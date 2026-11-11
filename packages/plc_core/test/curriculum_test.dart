import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

int word(ScanEngine e, String a) => e.memory.readWord(WordAddress.parse(a));

void setWord(ScanEngine e, String a, int v) =>
    e.memory.writeWord(WordAddress.parse(a), v);

double real(ScanEngine e, String a) => e.memory.readFloat(WordAddress.parse(a));

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

ScanEngine run(
  Instruction i, {
  Map<String, int> init = const {},
  Map<String, double> floats = const {},
}) {
  final e = engineFor([
    Rung([i]),
  ]);
  init.forEach((a, v) => setWord(e, a, v));
  floats.forEach((a, v) => e.memory.writeFloat(WordAddress.parse(a), v));
  e.scan();
  return e;
}

Instruction math(String op, String a, String b, String dest) =>
    Instruction.create(op, dest, source: a, mask: b);

void main() {
  group('F8 addressing', () {
    test('parses F8 words and float literals', () {
      final a = WordAddress.parse('f8:3');
      expect(a.toString(), 'F8:3');
      expect(a.index, 6);
      expect(() => WordAddress.parse('F8:16'), throwsFormatException);
      expect(Operand.parse('12.5'), const FloatConstant(12.5));
      expect(Operand.parse('7'), const Constant(7));
      expect(Operand.parse('F8:0'), WordAddress.parse('F8:0'));
    });

    test('memory round-trips 32-bit floats', () {
      final m = PlcMemory();
      final a = WordAddress.parse('F8:15');
      m.writeFloat(a, 3.5);
      expect(m.readFloat(a), 3.5);
      expect(BitFile.float.words, 32);
      final other = PlcMemory()..copyFrom(m, [BitFile.float]);
      expect(other.readFloat(a), 3.5);
    });
  });

  group('ONS', () {
    test('pulses one scan per rising edge', () {
      final e = engineFor([
        Rung([Xic('B3:0/0'), Ons('B3:0/1'), Ote('B3:0/2')]),
      ]);
      List<bool> scans() => [
        for (var i = 0; i < 3; i++) (e.scan(), bit(e, 'B3:0/2')).$2,
      ];
      e.memory.writeBit(BitAddress.parse('B3:0/0'), true);
      expect(scans(), [true, false, false]);
      e.memory.writeBit(BitAddress.parse('B3:0/0'), false);
      e.scan();
      expect(bit(e, 'B3:0/1'), isFalse);
      e.memory.writeBit(BitAddress.parse('B3:0/0'), true);
      expect(scans(), [true, false, false]);
    });
  });

  group('MOD / XPY / SWP', () {
    test('MOD remainder and division by zero', () {
      expect(word(run(math('MOD', '17', '5', 'N7:0')), 'N7:0'), 2);
      final e = run(
        math('MOD', 'N7:1', '0', 'N7:0'),
        init: {'N7:0': 9, 'N7:1': 4},
      );
      expect(word(e, 'N7:0'), 0);
      expect(bit(e, 'S:0/1'), isTrue);
      expect(bit(e, 'S:5/0'), isTrue);
    });

    test('XPY integer, clamp and EXPT alias', () {
      expect(word(run(math('XPY', '2', '10', 'N7:0')), 'N7:0'), 1024);
      final e = run(math('EXPT', '10', '9', 'N7:0'));
      expect(word(e, 'N7:0'), 32767);
      expect(bit(e, 'S:0/1'), isTrue);
      expect(
        Instruction.create('EXPT', 'N7:0', source: '2', mask: '2'),
        isA<Xpy>(),
      );
    });

    test('XPY float', () {
      final e = run(math('XPY', 'F8:0', '0.5', 'F8:1'), floats: {'F8:0': 16});
      expect(real(e, 'F8:1'), 4);
    });

    test('SWP swaps bytes and SWAP alias', () {
      final e = run(
        Instruction.create('SWAP', 'N7:1', source: 'N7:0'),
        init: {'N7:0': 0x12FF},
      );
      expect(word(e, 'N7:1'), 0xFF12.toSigned(16));
    });
  });

  group('float math and conversion', () {
    test('ADD SUB MUL DIV SQR in float', () {
      final f = {'F8:0': 6.0, 'F8:1': 4.0};
      expect(
        real(run(math('ADD', 'F8:0', 'F8:1', 'F8:2'), floats: f), 'F8:2'),
        10,
      );
      expect(
        real(run(math('SUB', 'F8:0', 'F8:1', 'F8:2'), floats: f), 'F8:2'),
        2,
      );
      expect(
        real(run(math('MUL', 'F8:0', '1.5', 'F8:2'), floats: f), 'F8:2'),
        9,
      );
      expect(
        real(run(math('DIV', 'F8:0', 'F8:1', 'F8:2'), floats: f), 'F8:2'),
        1.5,
      );
      expect(
        real(
          run(Instruction.create('SQR', 'F8:2', source: 'F8:1'), floats: f),
          'F8:2',
        ),
        2,
      );
    });

    test('integer sources into a float destination', () {
      final e = run(math('DIV', '7', '2', 'F8:0'));
      expect(real(e, 'F8:0'), 3.5);
    });

    test('MOV converts INT <-> REAL', () {
      var e = run(
        Instruction.create('MOV', 'F8:0', source: 'N7:0'),
        init: {'N7:0': -12},
      );
      expect(real(e, 'F8:0'), -12);
      e = run(
        Instruction.create('MOV', 'N7:0', source: 'F8:0'),
        floats: {'F8:0': 2.5},
      );
      expect(word(e, 'N7:0'), 3);
      e = run(
        Instruction.create('MOV', 'N7:0', source: 'F8:0'),
        floats: {'F8:0': 1e9},
      );
      expect(word(e, 'N7:0'), 32767);
      e = run(Instruction.create('MOV', 'F8:0', source: '12.5'));
      expect(real(e, 'F8:0'), 12.5);
    });
  });

  group('program json', () {
    test('round-trips the new instructions', () {
      final program = Program([
        Rung([
          Ons('B3:0/0'),
          math('MOD', 'N7:0', '3', 'N7:1'),
          math('XPY', 'F8:0', '2.5', 'F8:1'),
          Instruction.create('SWP', 'N7:2', source: 'N7:1'),
          Instruction.create('MOV', 'F8:2', source: '3.14'),
        ]),
      ]);
      final back = programFromJson(programToJson(program));
      expect(programToJson(back), programToJson(program));
      final ops = back.rungs.single.elements;
      expect(ops.map((e) => (e as Instruction).mnemonic), [
        'ONS',
        'MOD',
        'XPY',
        'SWP',
        'MOV',
      ]);
      expect((ops[4] as Mov).source, const FloatConstant(3.14));
    });
  });
}

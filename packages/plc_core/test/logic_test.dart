import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

int word(ScanEngine e, String a) => e.memory.readWord(WordAddress.parse(a));

void setWord(ScanEngine e, String a, int v) => e.memory.writeWord(WordAddress.parse(a), v);

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

/// Runs one scan of `[logic]` (always true) and returns the engine.
ScanEngine run(Instruction logic, {Map<String, int> init = const {}}) {
  final e = engineFor([
    Rung([logic]),
  ]);
  init.forEach((a, v) => setWord(e, a, v));
  e.scan();
  return e;
}

void expectFlags(ScanEngine e, {bool z = false, bool s = false}) {
  expect(
    [bit(e, 'S:0/0'), bit(e, 'S:0/1'), bit(e, 'S:0/2'), bit(e, 'S:0/3')],
    [false, false, z, s],
    reason: 'S:0 carry, overflow, zero, sign',
  );
}

void main() {
  group('Instruction.create', () {
    test('builds the logic instructions', () {
      final and = Instruction.create('AND', 'N7:2', source: 'N7:0', mask: '255') as And;
      expect(and.sourceA, WordAddress.parse('N7:0'));
      expect(and.sourceB, const Constant(255));
      expect(and.dest, WordAddress.parse('N7:2'));
      expect(and.isOutput, isTrue);
      expect(and.target, 'N7:2');
      expect(Instruction.create('or', 'N7:2', source: '1', mask: '2'), isA<Or>());
      expect(Instruction.create('XOR', 'N7:2', source: '1', mask: '2'), isA<Xor>());
      final not = Instruction.create('NOT', 'N7:2', source: 'N7:0') as Not;
      expect(not.source, WordAddress.parse('N7:0'));
      expect(not.mnemonic, 'NOT');
    });

    test('rejects bad operands', () {
      expect(() => Instruction.create('AND', 'N7:2', source: 'zz', mask: '1'), throwsFormatException);
      expect(() => Instruction.create('NOT', 'N7:2', source: ''), throwsFormatException);
    });
  });

  group('calculation', () {
    test('AND masks bits', () {
      final e = run(And('N7:0', '255', 'N7:1'), init: {'N7:0': 0x1234});
      expect(word(e, 'N7:1'), 0x34);
      expect(word(run(And('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 0x0FF0, 'N7:1': 0x00FF}), 'N7:2'), 0x00F0);
    });

    test('OR sets bits', () {
      expect(word(run(Or('N7:0', '15', 'N7:1'), init: {'N7:0': 0x30}), 'N7:1'), 0x3F);
    });

    test('XOR toggles bits', () {
      expect(word(run(Xor('N7:0', '255', 'N7:1'), init: {'N7:0': 0x0FF0}), 'N7:1'), 0x0F0F);
      expect(word(run(Xor('N7:0', 'N7:0', 'N7:1'), init: {'N7:0': 1234}), 'N7:1'), 0);
    });

    test('NOT is the one\'s complement', () {
      expect(word(run(Not('N7:0', 'N7:1'), init: {'N7:0': 0}), 'N7:1'), -1);
      expect(word(run(Not('N7:0', 'N7:1'), init: {'N7:0': -1}), 'N7:1'), 0);
      expect(word(run(Not('N7:0', 'N7:1'), init: {'N7:0': 0x00FF}), 'N7:1'), -256);
    });

    test('works on signed 16-bit words', () {
      expect(word(run(And('N7:0', '-1', 'N7:1'), init: {'N7:0': -32768}), 'N7:1'), -32768);
      expect(word(run(Or('N7:0', '32767', 'N7:1'), init: {'N7:0': -32768}), 'N7:1'), -1);
      expect(word(run(Xor('-1', '32767', 'N7:1')), 'N7:1'), -32768);
    });
  });

  group('status bits', () {
    test('zero result sets Z', () {
      expectFlags(run(And('N7:0', '255', 'N7:1'), init: {'N7:0': 0x100}), z: true);
    });

    test('negative result sets S', () {
      expectFlags(run(Not('N7:0', 'N7:1'), init: {'N7:0': 0}), s: true);
    });

    test('positive result clears Z and S', () {
      expectFlags(run(Or('N7:0', '1', 'N7:1'), init: {'N7:0': 0}));
    });

    test('carry and overflow are cleared', () {
      final e = engineFor([
        Rung([Add('N7:0', '1', 'N7:1')]),
        Rung([Not('N7:2', 'N7:3')]),
      ]);
      setWord(e, 'N7:0', 32767);
      e.scan();
      // ADD overflowed (V set), then NOT ran later in the same scan and cleared it.
      expectFlags(e, s: true);
    });
  });

  group('rung power', () {
    test('false rung does not execute', () {
      final e = engineFor([
        Rung([Xic('B3:0/0'), Not('N7:0', 'N7:1')]),
      ]);
      setWord(e, 'N7:1', 5);
      e.scan();
      expect(word(e, 'N7:1'), 5);
      expectFlags(e);
    });

    test('executes every scan while true', () {
      final e = engineFor([
        Rung([Xic('B3:0/0'), Or('N7:0', '1', 'N7:1')]),
      ]);
      e.memory.writeBit(BitAddress.parse('B3:0/0'), true);
      e.scan();
      expect(word(e, 'N7:1'), 1);
      setWord(e, 'N7:0', 2);
      e.scan();
      expect(word(e, 'N7:1'), 3);
    });

    test('power passes through to the next instruction', () {
      final e = engineFor([
        Rung([Xor('N7:0', '1', 'N7:1'), Ote('B3:0/1')]),
      ]);
      e.scan();
      expect(bit(e, 'B3:0/1'), isTrue);
    });
  });

  group('JSON', () {
    test('round-trips the logic instructions', () {
      final program = Program([
        Rung([And('N7:0', '255', 'N7:1'), Or('N7:0', 'N7:3', 'N7:2')]),
        Rung([Xor('1', '2', 'N7:4'), Not('N7:0', 'N7:5')]),
      ]);
      final json = programToJson(program);
      final back = programFromJson(json);
      expect(programToJson(back), json);
      final first = back.rungs[0].elements;
      expect(first[0], isA<And>());
      expect((first[0] as And).sourceB, const Constant(255));
      expect(first[1], isA<Or>());
      expect(back.rungs[1].elements[0], isA<Xor>());
      expect((back.rungs[1].elements[1] as Not).source, WordAddress.parse('N7:0'));
    });

    test('writes the shared source/mask keys', () {
      final json = programToJson(Program([
        Rung([And('N7:0', '255', 'N7:1'), Not('N7:2', 'N7:3')]),
      ]));
      final elements = ((json['rungs']! as List).single as Map)['elements']! as List;
      expect(elements[0], {'op': 'AND', 'address': 'N7:1', 'source': 'N7:0', 'mask': '255'});
      expect(elements[1], {'op': 'NOT', 'address': 'N7:3', 'source': 'N7:2'});
    });
  });
}

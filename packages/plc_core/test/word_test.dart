import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

int word(ScanEngine e, String a) => e.memory.readWord(WordAddress.parse(a));

void setWord(ScanEngine e, String a, int v) => e.memory.writeWord(WordAddress.parse(a), v);

void main() {
  group('word addresses', () {
    test('parse and print canonically', () {
      for (final (input, printed) in [
        ('n7:5', 'N7:5'),
        ('B3:15', 'B3:15'),
        (' O:0 ', 'O:0'),
        ('I:0', 'I:0'),
        ('S:1', 'S:1'),
        ('t4:3.acc', 'T4:3.ACC'),
        ('T4:3.PRE', 'T4:3.PRE'),
        ('C5:15.ACC', 'C5:15.ACC'),
        ('c5:0.pre', 'C5:0.PRE'),
        ('N7:31', 'N7:31'),
      ]) {
        expect(WordAddress.parse(input).toString(), printed, reason: input);
      }
    });

    test('reject bad or out of range input', () {
      for (final bad in [
        '', 'N7', 'N7:32', 'N7:-1', 'B3:16', 'O:1', 'I:1', 'S:2', 'T4:0', 'T4:16.ACC',
        'C5:0.DN', 'T4:0.XX', 'N7:0/3', 'X1:0', 'N8:0', 'N7:0.ACC',
      ]) {
        expect(() => WordAddress.parse(bad), throwsFormatException, reason: bad);
      }
    });

    test('index points into the file array', () {
      expect(WordAddress.parse('N7:4').index, 4);
      expect(WordAddress.parse('T4:2.PRE').index, 7);
      expect(WordAddress.parse('C5:2.ACC').index, 8);
    });

    test('canonicalAddress accepts word addresses', () {
      expect(canonicalAddress('n7:3'), 'N7:3');
      expect(canonicalAddress('n7:3/1'), 'N7:3/1');
      expect(canonicalAddress('t4:1'), 'T4:1');
      expect(() => canonicalAddress('N7:99'), throwsFormatException);
    });
  });

  group('operands', () {
    test('constants: decimal range', () {
      expect(Operand.parse('100'), const Constant(100));
      expect(Operand.parse('-32768'), const Constant(-32768));
      expect(Operand.parse('32767'), const Constant(32767));
      expect(() => Operand.parse('32768'), throwsFormatException);
      expect(() => Operand.parse('-32769'), throwsFormatException);
    });

    test('hex is accepted only for masks and printed as 00FFh', () {
      for (final text in ['00FFh', '0x00FF', '00ffh', 'FFh']) {
        expect(Operand.parse(text, mask: true), const Constant(255), reason: text);
      }
      expect(Operand.parse('FFFFh', mask: true), const Constant(-1));
      expect(Operand.parse('00FFh', mask: true).format(hex: true), '00FFh');
      expect(const Constant(-1).format(hex: true), 'FFFFh');
      expect(() => Operand.parse('00FFh'), throwsFormatException);
      expect(() => Operand.parse('0x00FF'), throwsFormatException);
      expect(() => Operand.parse('12345h', mask: true), throwsFormatException);
    });

    test('addresses are operands too', () {
      expect(Operand.parse('t4:0.acc'), WordAddress.parse('T4:0.ACC'));
    });
  });

  group('Instruction.create', () {
    test('builds MOV, MVM and CLR', () {
      final mov = Instruction.create('mov', 'N7:1', source: '100');
      expect(mov, isA<Mov>());
      expect(mov.target, 'N7:1');
      expect(mov.isOutput, isTrue);
      final mvm = Instruction.create('MVM', 'O:0', source: 'N7:0', mask: '000Fh') as Mvm;
      expect(mvm.mask.format(hex: true), '000Fh');
      expect(Instruction.create('CLR', 'N7:2'), isA<Clr>());
    });

    test('rejects bad operands', () {
      expect(() => Instruction.create('MOV', 'N7:1'), throwsFormatException);
      expect(() => Instruction.create('MOV', '5', source: '1'), throwsFormatException);
      expect(() => Instruction.create('MOV', 'N7:32', source: '1'), throwsFormatException);
      expect(() => Instruction.create('MOV', 'N7:1', source: '40000'), throwsFormatException);
      expect(() => Instruction.create('MVM', 'N7:1', source: '1', mask: ''), throwsFormatException);
      expect(() => Instruction.create('MVM', 'N7:1', source: '1', mask: 'zz'), throwsFormatException);
      expect(() => Instruction.create('CLR', '3'), throwsFormatException);
    });
  });

  group('execution', () {
    test('MOV copies a constant and a word, negative values included', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Mov('-5', 'N7:0'), Mov('N7:0', 'N7:1')]),
      ]);
      e.inputImage = 1;
      e.scan();
      expect(word(e, 'N7:0'), -5);
      expect(word(e, 'N7:1'), -5);
      expect(e.memory.word(BitFile.integer, 0), 0xFFFB);
    });

    test('rung false does nothing', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Mov('7', 'N7:0'), Clr('N7:1'), Mvm('1', '1', 'N7:2')]),
      ]);
      setWord(e, 'N7:1', 9);
      e.scan();
      expect([word(e, 'N7:0'), word(e, 'N7:1'), word(e, 'N7:2')], [0, 9, 0]);
    });

    test('MOV executes every scan while true and passes power on', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Mov('N7:5', 'N7:6'), Ote('O:0/0')]),
      ]);
      e.inputImage = 1;
      setWord(e, 'N7:5', 1);
      e.scan();
      expect(word(e, 'N7:6'), 1);
      expect(e.outputImage, 1);
      setWord(e, 'N7:5', 2);
      e.scan();
      expect(word(e, 'N7:6'), 2);
    });

    test('MVM replaces only the masked bits', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Mvm('N7:0', '00FFh', 'N7:1')]),
      ]);
      e.inputImage = 1;
      setWord(e, 'N7:0', 0x1234);
      setWord(e, 'N7:1', 0x5678);
      e.scan();
      expect(e.memory.word(BitFile.integer, 1), 0x5634);
    });

    test('MVM with a constant source, a decimal mask and a mask held in a word', () {
      final e = engineFor([
        Rung([Mvm('-1', '15', 'N7:0'), Mvm('0', 'N7:9', 'N7:1')]),
      ]);
      setWord(e, 'N7:1', 0x00F7);
      setWord(e, 'N7:9', 0x0003);
      e.scan();
      expect(e.memory.word(BitFile.integer, 0), 0x000F);
      expect(e.memory.word(BitFile.integer, 1), 0x00F4);
    });

    test('MVM into the output word drives the physical outputs', () {
      final e = engineFor([
        Rung([Mov('100', 'N7:0'), Mvm('N7:0', '000Fh', 'O:0')]),
      ]);
      e.scan();
      expect(e.outputImage, 4);
    });

    test('CLR zeroes the destination', () {
      final e = engineFor([Rung([Clr('N7:3')])]);
      setWord(e, 'N7:3', 1234);
      e.scan();
      expect(word(e, 'N7:3'), 0);
    });

    test('T4 / C5 .ACC and .PRE as source and destination', () {
      final e = engineFor([
        Rung([
          Mov('T4:0.ACC', 'N7:0'),
          Mov('T4:0.PRE', 'N7:1'),
          Mov('C5:1.ACC', 'N7:2'),
          Mov('42', 'C5:1.PRE'),
          Mov('-3', 'C5:2.ACC'),
          Clr('T4:3.ACC'),
          Mov('N7:2', 'T4:4.PRE'),
        ]),
      ]);
      e.memory.setPre(const ElementAddress(BitFile.timer, 0), 30);
      e.memory.setAcc(const ElementAddress(BitFile.timer, 0), 12);
      e.memory.setAcc(const ElementAddress(BitFile.counter, 1), 7);
      e.memory.setAcc(const ElementAddress(BitFile.timer, 3), 99);
      e.scan();
      expect(word(e, 'N7:0'), 12);
      expect(word(e, 'N7:1'), 30);
      expect(word(e, 'N7:2'), 7);
      expect(e.memory.pre(const ElementAddress(BitFile.counter, 1)), 42);
      expect(e.memory.acc(const ElementAddress(BitFile.counter, 2)), -3);
      expect(e.memory.acc(const ElementAddress(BitFile.timer, 3)), 0);
      expect(e.memory.pre(const ElementAddress(BitFile.timer, 4)), 7);
    });

    test('B3 words and S:1 are word operands', () {
      final e = engineFor([Rung([Mov('B3:2', 'N7:0'), Mov('S:1', 'N7:1')])]);
      e.memory.setWord(BitFile.bit, 2, 0x8001);
      e.scan();
      expect(word(e, 'N7:0'), -32767);
      expect(word(e, 'N7:1'), isNot(0)); // first-scan bit S:1/15 is set
    });

    test('writing I:0 is overwritten by the next input copy', () {
      final e = engineFor([Rung([Mov('255', 'I:0')])]);
      e.inputImage = 3;
      e.scan();
      expect(word(e, 'I:0'), 255);
      e.scan();
      e.scan();
      expect(e.memory.word(BitFile.input, 0), 255); // the move runs again after the copy
    });

    test('MOV works inside a branch path', () {
      final e = engineFor([
        Rung([
          Branch([
            [Xic('I:0/0'), Mov('1', 'N7:0')],
            [Xic('I:0/1'), Mov('2', 'N7:1')],
          ]),
        ]),
      ]);
      e.inputImage = 2;
      e.scan();
      expect([word(e, 'N7:0'), word(e, 'N7:1')], [0, 2]);
    });
  });

  group('N7 bits', () {
    test('parse, print and use in bit instructions', () {
      expect(BitAddress.parse('n7:0/3').toString(), 'N7:0/3');
      expect(() => BitAddress.parse('N7:32/0'), throwsFormatException);
      expect(() => BitAddress.parse('N7:0/16'), throwsFormatException);
      final e = engineFor([
        Rung([Xic('N7:0/3'), Ote('O:0/0')]),
        Rung([Xio('N7:0/3'), Ote('O:0/1')]),
        Rung([Xic('I:0/0'), Otl('N7:1/15')]),
      ]);
      e.scan();
      expect(e.outputImage, 2);
      setWord(e, 'N7:0', 8);
      e.inputImage = 1;
      e.scan();
      expect(e.outputImage, 1);
      expect(word(e, 'N7:1'), -32768);
    });
  });

  test('PlcMemory.copyFrom copies whole files', () {
    final a = PlcMemory()..setWord(BitFile.integer, 3, 77);
    final b = PlcMemory()..copyFrom(a, [BitFile.integer]);
    expect(b.word(BitFile.integer, 3), 77);
  });
}

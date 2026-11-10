import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

int word(ScanEngine e, String a) => e.memory.readWord(WordAddress.parse(a));

void setWord(ScanEngine e, String a, int v) => e.memory.writeWord(WordAddress.parse(a), v);

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

/// Runs one scan of `[math]` (always true) and returns the engine.
ScanEngine run(Instruction math, {Map<String, int> init = const {}}) {
  final e = engineFor([
    Rung([math]),
  ]);
  init.forEach((a, v) => setWord(e, a, v));
  e.scan();
  return e;
}

void expectFlags(ScanEngine e, {bool c = false, bool v = false, bool z = false, bool s = false}) {
  expect(
    [bit(e, 'S:0/0'), bit(e, 'S:0/1'), bit(e, 'S:0/2'), bit(e, 'S:0/3')],
    [c, v, z, s],
    reason: 'S:0 carry, overflow, zero, sign',
  );
}

void main() {
  group('Instruction.create', () {
    test('builds the math instructions', () {
      final add = Instruction.create('ADD', 'N7:2', source: 'N7:0', mask: '5') as Add;
      expect(add.sourceA, WordAddress.parse('N7:0'));
      expect(add.sourceB, const Constant(5));
      expect(add.isOutput, isTrue);
      expect(add.target, 'N7:2');
      expect(Instruction.create('sub', 'N7:2', source: '1', mask: '2'), isA<Sub>());
      expect(Instruction.create('MUL', 'N7:2', source: '1', mask: '2'), isA<Mul>());
      expect(Instruction.create('DIV', 'N7:2', source: '1', mask: '2'), isA<Div>());
      expect(Instruction.create('NEG', 'N7:2', source: 'N7:0'), isA<Neg>());
      expect(Instruction.create('SQR', 'N7:2', source: '9'), isA<Sqr>());
      final scl = Instruction.create('SCL', 'N7:1', source: 'N7:0', mask: '610', offset: '-3') as Scl;
      expect(scl.rate, const Constant(610));
      expect(scl.offset, const Constant(-3));
    });

    test('rejects bad operands', () {
      expect(() => Instruction.create('ADD', '5', source: '1', mask: '2'), throwsFormatException);
      expect(() => Instruction.create('ADD', 'N7:0', source: '1'), throwsFormatException);
      expect(() => Instruction.create('SCL', 'N7:0', source: '1', mask: '2'), throwsFormatException);
      expect(() => Instruction.create('MUL', 'N7:0', source: '40000', mask: '2'), throwsFormatException);
    });
  });

  group('S file', () {
    test('S:0 flag bits and S:5/0 parse', () {
      expect(BitAddress.parse('S:0/2').toString(), 'S:0/2');
      expect(BitAddress.parse('S:5/0'), overflowTrapBit);
      expect(() => BitAddress.parse('S:6/0'), throwsFormatException);
    });

    test('flags are readable by contacts', () {
      final e = engineFor([
        Rung([Add('N7:0', '0', 'N7:1')]),
        Rung([Xic('S:0/2'), Ote('O:0/0')]),
        Rung([Xic('S:0/3'), Ote('O:0/1')]),
      ]);
      e.scan();
      expect(e.outputImage, 1); // zero
      setWord(e, 'N7:0', -4);
      e.scan();
      expect(e.outputImage, 2); // sign
    });
  });

  group('ADD / SUB / MUL', () {
    test('add words and constants, negatives', () {
      expect(word(run(Add('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 100, 'N7:1': -250}), 'N7:2'), -150);
      expect(word(run(Add('N7:0', '7', 'N7:2'), init: {'N7:0': 3}), 'N7:2'), 10);
      expect(word(run(Add('-3', '-4', 'N7:2')), 'N7:2'), -7);
    });

    test('add flags: zero, sign, carry', () {
      expectFlags(run(Add('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 5, 'N7:1': -5}), z: true, c: true);
      expectFlags(run(Add('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 1, 'N7:1': 2}));
      expectFlags(run(Add('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': -1, 'N7:1': -2}), s: true, c: true);
      expectFlags(run(Add('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 100, 'N7:1': -250}), s: true);
    });

    test('add overflow clamps, sets V and S:5/0', () {
      final e = run(Add('N7:0', '1', 'N7:2'), init: {'N7:0': 32767});
      expect(word(e, 'N7:2'), 32767);
      expectFlags(e, v: true);
      expect(bit(e, 'S:5/0'), isTrue);
      final n = run(Add('N7:0', '-1', 'N7:2'), init: {'N7:0': -32768});
      expect(word(n, 'N7:2'), -32768);
      expectFlags(n, v: true, s: true, c: true);
    });

    test('sub, borrow and negative results', () {
      expect(word(run(Sub('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 10, 'N7:1': 4}), 'N7:2'), 6);
      expectFlags(run(Sub('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 10, 'N7:1': 4}));
      final e = run(Sub('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 4, 'N7:1': 10});
      expect(word(e, 'N7:2'), -6);
      expectFlags(e, c: true, s: true);
      expectFlags(run(Sub('N7:0', 'N7:0', 'N7:2'), init: {'N7:0': 9}), z: true);
      final o = run(Sub('N7:0', '1', 'N7:2'), init: {'N7:0': -32768});
      expect(word(o, 'N7:2'), -32768);
      expectFlags(o, v: true, s: true);
    });

    test('mul, negatives and overflow', () {
      expect(word(run(Mul('N7:0', '-3', 'N7:2'), init: {'N7:0': 11}), 'N7:2'), -33);
      expect(word(run(Mul('-4', '-5', 'N7:2')), 'N7:2'), 20);
      expectFlags(run(Mul('N7:0', '0', 'N7:2'), init: {'N7:0': 11}), z: true);
      final e = run(Mul('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 300, 'N7:1': 300});
      expect(word(e, 'N7:2'), 32767);
      expectFlags(e, v: true);
      expect(bit(e, 'S:5/0'), isTrue);
      final n = run(Mul('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 300, 'N7:1': -300});
      expect(word(n, 'N7:2'), -32768);
      expectFlags(n, v: true, s: true);
    });
  });

  group('DIV', () {
    int div(int a, int b) => word(run(Div('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': a, 'N7:1': b}), 'N7:2');

    test('rounds to nearest, halves away from zero', () {
      expect(div(10, 4), 3);
      expect(div(-10, 4), -3);
      expect(div(10, -4), -3);
      expect(div(-10, -4), 3);
      expect(div(9, 4), 2);
      expect(div(-9, 4), -2);
      expect(div(11, 4), 3);
      expect(div(7, 1), 7);
      expect(word(run(Div('N7:0', '10', 'N7:2'), init: {'N7:0': 1005}), 'N7:2'), 101);
    });

    test('flags', () {
      expectFlags(run(Div('N7:0', '4', 'N7:2'), init: {'N7:0': 1}), z: true);
      expectFlags(run(Div('N7:0', '4', 'N7:2'), init: {'N7:0': -8}), s: true);
    });

    test('divide by zero: 32767, overflow, S:5/0', () {
      final e = run(Div('N7:0', 'N7:1', 'N7:2'), init: {'N7:0': 5});
      expect(word(e, 'N7:2'), 32767);
      expectFlags(e, v: true);
      expect(bit(e, 'S:5/0'), isTrue);
    });

    test('-32768 / -1 overflows', () {
      final e = run(Div('N7:0', '-1', 'N7:2'), init: {'N7:0': -32768});
      expect(word(e, 'N7:2'), 32767);
      expectFlags(e, v: true);
    });
  });

  group('NEG / SQR / SCL', () {
    test('neg', () {
      expect(word(run(Neg('N7:0', 'N7:1'), init: {'N7:0': 25}), 'N7:1'), -25);
      final n = run(Neg('N7:0', 'N7:1'), init: {'N7:0': -25});
      expect(word(n, 'N7:1'), 25);
      expectFlags(n);
      expectFlags(run(Neg('N7:0', 'N7:1'), init: {'N7:0': 25}), s: true);
      expectFlags(run(Neg('0', 'N7:1')), z: true);
      expect(word(run(Neg('7', 'N7:1')), 'N7:1'), -7);
    });

    test('neg of -32768 overflows', () {
      final e = run(Neg('N7:0', 'N7:1'), init: {'N7:0': -32768});
      expect(word(e, 'N7:1'), 32767);
      expectFlags(e, v: true);
      expect(bit(e, 'S:5/0'), isTrue);
    });

    test('sqr rounds to nearest', () {
      expect(word(run(Sqr('N7:0', 'N7:1'), init: {'N7:0': 144}), 'N7:1'), 12);
      expect(word(run(Sqr('N7:0', 'N7:1'), init: {'N7:0': 10}), 'N7:1'), 3);
      expect(word(run(Sqr('N7:0', 'N7:1'), init: {'N7:0': 12}), 'N7:1'), 3);
      expect(word(run(Sqr('2', 'N7:1')), 'N7:1'), 1);
      expectFlags(run(Sqr('N7:0', 'N7:1'), init: {'N7:0': 0}), z: true);
    });

    test('sqr of a negative uses |x| and sets carry', () {
      final e = run(Sqr('N7:0', 'N7:1'), init: {'N7:0': -144});
      expect(word(e, 'N7:1'), 12);
      expectFlags(e, c: true);
      expectFlags(run(Sqr('N7:0', 'N7:1'), init: {'N7:0': 144}));
    });

    test('scl scales with rate and offset', () {
      expect(word(run(Scl('N7:0', '610', '0', 'N7:1'), init: {'N7:0': 16383}), 'N7:1'), 999);
      expect(word(run(Scl('N7:0', '5000', '10', 'N7:1'), init: {'N7:0': 100}), 'N7:1'), 60);
      expect(word(run(Scl('N7:0', 'N7:2', 'N7:3', 'N7:1'), init: {'N7:0': 3, 'N7:2': 5000, 'N7:3': -1}), 'N7:1'), 1);
      expect(word(run(Scl('N7:0', '-10000', '0', 'N7:1'), init: {'N7:0': 40}), 'N7:1'), -40);
      expect(word(run(Scl('5', '5000', '0', 'N7:1')), 'N7:1'), 3); // 2.5 -> 3
      expect(word(run(Scl('-5', '5000', '0', 'N7:1')), 'N7:1'), -3);
    });

    test('scl flags and overflow', () {
      expectFlags(run(Scl('N7:0', '100', '0', 'N7:1'), init: {'N7:0': 10}), z: true);
      final e = run(Scl('N7:0', '30000', '0', 'N7:1'), init: {'N7:0': 20000});
      expect(word(e, 'N7:1'), 32767);
      expectFlags(e, v: true);
      expect(bit(e, 'S:5/0'), isTrue);
    });
  });

  group('execution', () {
    test('rung false does nothing and leaves the flags alone', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Add('1', '1', 'N7:0')]),
      ]);
      e.scan();
      expect(word(e, 'N7:0'), 0);
      expect(e.memory.word(BitFile.status, 0), 0);
      e.inputImage = 1;
      e.scan();
      expect(word(e, 'N7:0'), 2);
      e.inputImage = 0;
      setWord(e, 'N7:0', 99);
      e.scan();
      expect(word(e, 'N7:0'), 99);
    });

    test('power passes through unchanged', () {
      final e = engineFor([
        Rung([Add('1', '1', 'N7:0'), Ote('O:0/0')]),
      ]);
      e.scan();
      expect(e.outputImage, 1);
    });

    test('runs every scan while true', () {
      final e = engineFor([
        Rung([Add('N7:0', '1', 'N7:0')]),
      ]);
      e.scan();
      e.scan();
      e.scan();
      expect(word(e, 'N7:0'), 3);
    });

    test('inside a branch', () {
      final e = engineFor([
        Rung([
          Branch([
            [Xic('I:0/0'), Add('2', '3', 'N7:0')],
            [Xic('I:0/1'), Mul('2', '3', 'N7:1')],
          ]),
          Ote('O:0/0'),
        ]),
      ]);
      e.inputImage = 2;
      e.scan();
      expect(word(e, 'N7:0'), 0);
      expect(word(e, 'N7:1'), 6);
      expect(e.outputImage, 1);
    });

    test('S:5/0 stays latched until cleared by the user', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Add('32767', '1', 'N7:0')]),
        Rung([Xic('I:0/1'), Add('1', '1', 'N7:1')]),
      ]);
      e.inputImage = 1;
      e.scan();
      expect(bit(e, 'S:5/0'), isTrue);
      e.inputImage = 2;
      e.scan();
      expectFlags(e); // flags follow the last instruction
      expect(bit(e, 'S:5/0'), isTrue);
      e.memory.writeBit(overflowTrapBit, false);
      e.scan();
      expect(bit(e, 'S:5/0'), isFalse);
    });

    test('scaling chain feeds a compare', () {
      final e = engineFor([
        Rung([Scl('N7:0', '610', '0', 'N7:1')]),
        Rung([Add('N7:1', '5', 'N7:2')]),
        Rung([Div('N7:2', '10', 'N7:3')]),
        Rung([Grt('N7:3', '50'), Ote('O:0/0')]),
      ]);
      setWord(e, 'N7:0', 16383);
      e.scan();
      expect([word(e, 'N7:1'), word(e, 'N7:2'), word(e, 'N7:3')], [999, 1004, 100]);
      expect(e.outputImage, 1);
      setWord(e, 'N7:0', 1000);
      e.scan();
      expect(e.outputImage, 0);
    });
  });
}

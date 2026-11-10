import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

/// Scans `[cmp, OTE O:0/0]` with N7:0 = [a] and N7:1 = [b]; returns whether O:0/0 came on.
bool out(CompareInstruction cmp, int a, int b) {
  final e = ScanEngine(Program([
    Rung([cmp, Ote('O:0/0')]),
  ]))
    ..prescan();
  e.memory.writeWord(WordAddress.parse('N7:0'), a);
  e.memory.writeWord(WordAddress.parse('N7:1'), b);
  e.scan();
  return e.outputImage == 1;
}

bool limit(int low, int test, int high) {
  final e = ScanEngine(Program([
    Rung([Lim('$low', 'N7:0', '$high'), Ote('O:0/0')]),
  ]))
    ..prescan();
  e.memory.writeWord(WordAddress.parse('N7:0'), test);
  e.scan();
  return e.outputImage == 1;
}

void main() {
  group('Instruction.create', () {
    test('builds the compare instructions and LIM', () {
      for (final (m, type) in [
        ('EQU', isA<Equ>()),
        ('neq', isA<Neq>()),
        ('LES', isA<Les>()),
        ('LEQ', isA<Leq>()),
        ('GRT', isA<Grt>()),
        ('GEQ', isA<Geq>()),
      ]) {
        final i = Instruction.create(m, 'n7:0', source: '10');
        expect(i, type, reason: m);
        expect(i.isOutput, isFalse);
        expect(i.target, 'N7:0');
        expect((i as CompareInstruction).sourceB, const Constant(10));
      }
      final lim = Instruction.create('LIM', 'N7:3', source: '5', mask: 'N7:4') as Lim;
      expect(lim.low, const Constant(5));
      expect(lim.test, WordAddress.parse('N7:3'));
      expect(lim.high, WordAddress.parse('N7:4'));
      expect(lim.isOutput, isFalse);
      expect(lim.target, 'N7:3');
    });

    test('rejects bad operands', () {
      expect(() => Instruction.create('EQU', '5', source: '1'), throwsFormatException);
      expect(() => Instruction.create('EQU', 'N7:0'), throwsFormatException);
      expect(() => Instruction.create('GRT', 'N7:0', source: '40000'), throwsFormatException);
      expect(() => Instruction.create('LIM', 'N7:0', source: '1'), throwsFormatException);
      expect(() => Instruction.create('LIM', 'zz', source: '1', mask: '2'), throwsFormatException);
    });
  });

  group('compare execution', () {
    test('each comparison, with the value below, equal and above', () {
      // (a, b) pairs: a < b, a == b, a > b
      const pairs = [(1, 2), (2, 2), (3, 2)];
      final cases = <(CompareInstruction Function(), List<bool>)>[
        (() => Equ('N7:0', 'N7:1'), [false, true, false]),
        (() => Neq('N7:0', 'N7:1'), [true, false, true]),
        (() => Les('N7:0', 'N7:1'), [true, false, false]),
        (() => Leq('N7:0', 'N7:1'), [true, true, false]),
        (() => Grt('N7:0', 'N7:1'), [false, false, true]),
        (() => Geq('N7:0', 'N7:1'), [false, true, true]),
      ];
      for (final (make, expected) in cases) {
        final cmp = make();
        for (var i = 0; i < pairs.length; i++) {
          expect(out(cmp, pairs[i].$1, pairs[i].$2), expected[i], reason: '${cmp.mnemonic} ${pairs[i]}');
        }
      }
    });

    test('values are compared as signed 16-bit', () {
      expect(out(Les('N7:0', 'N7:1'), -5, 3), isTrue);
      expect(out(Grt('N7:0', 'N7:1'), -5, 3), isFalse);
      expect(out(Grt('N7:0', 'N7:1'), -3, -5), isTrue);
      expect(out(Les('N7:0', 'N7:1'), -32768, 32767), isTrue);
      expect(out(Geq('N7:0', 'N7:1'), -32768, -32768), isTrue);
    });

    test('constant operands, negatives included', () {
      expect(out(Equ('N7:0', '-7'), -7, 0), isTrue);
      expect(out(Equ('N7:0', '-7'), 7, 0), isFalse);
      expect(out(Grt('N7:0', '0'), 1, 0), isTrue);
      expect(out(Les('N7:0', '-1'), -2, 0), isTrue);
      expect(out(Neq('N7:0', '32767'), 32767, 0), isFalse);
    });

    test('rung false keeps the output off, and the compare writes nothing', () {
      final e = ScanEngine(Program([
        Rung([Xic('I:0/0'), Equ('N7:0', '0'), Ote('O:0/0')]),
      ]))
        ..prescan();
      e.scan();
      expect(e.outputImage, 0);
      e.inputImage = 1;
      e.scan();
      expect(e.outputImage, 1);
      expect(e.memory.readWord(WordAddress.parse('N7:0')), 0);
    });

    test('works inside a branch and reads timer words', () {
      final e = ScanEngine(Program([
        Rung([
          Branch([
            [Grt('N7:0', '10')],
            [Xic('I:0/0')],
          ]),
          Ote('O:0/0'),
        ]),
        Rung([Geq('T4:0.ACC', 'T4:0.PRE'), Ote('O:0/1')]),
      ]))
        ..prescan();
      e.scan();
      expect(e.outputImage & 1, 0);
      e.memory.writeWord(WordAddress.parse('N7:0'), 11);
      e.scan();
      expect(e.outputImage & 1, 1);
      e.memory.writeWord(WordAddress.parse('N7:0'), 0);
      e.inputImage = 1;
      e.scan();
      expect(e.outputImage & 1, 1);
      expect((e.outputImage >> 1) & 1, 1); // ACC 0 >= PRE 0
    });
  });

  group('LIM', () {
    test('low <= high: true inside the limits, inclusive', () {
      expect(limit(10, 10, 20), isTrue);
      expect(limit(10, 15, 20), isTrue);
      expect(limit(10, 20, 20), isTrue);
      expect(limit(10, 9, 20), isFalse);
      expect(limit(10, 21, 20), isFalse);
      expect(limit(-10, -3, 5), isTrue);
      expect(limit(-10, -11, 5), isFalse);
    });

    test('low > high: true outside the (high, low) gap, inclusive', () {
      expect(limit(20, 20, 10), isTrue);
      expect(limit(20, 25, 10), isTrue);
      expect(limit(20, 10, 10), isTrue);
      expect(limit(20, 5, 10), isTrue);
      expect(limit(20, 15, 10), isFalse);
      expect(limit(20, 11, 10), isFalse);
      expect(limit(5, -5, -10), isFalse);
      expect(limit(5, -10, -10), isTrue);
    });

    test('low == high behaves like EQU', () {
      expect(limit(7, 7, 7), isTrue);
      expect(limit(7, 6, 7), isFalse);
    });

    test('addresses as limits, constant as test value, rung false, branch', () {
      final e = ScanEngine(Program([
        Rung([
          Xic('I:0/1'),
          Branch([
            [Lim('N7:1', 'N7:0', 'N7:2')],
            [Lim('0', '5', '10')],
          ]),
          Ote('O:0/0'),
        ]),
      ]))
        ..prescan();
      void put(String a, int v) => e.memory.writeWord(WordAddress.parse(a), v);
      put('N7:1', 100);
      put('N7:2', 200);
      put('N7:0', 150);
      e.scan();
      expect(e.outputImage, 0, reason: 'rung-in false');
      e.inputImage = 2;
      e.scan();
      expect(e.outputImage, 1);
    });
  });
}

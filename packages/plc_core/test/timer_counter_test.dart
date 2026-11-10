import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

const t0 = ElementAddress(BitFile.timer, 0);
const c0 = ElementAddress(BitFile.counter, 0);

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

void scanFor(ScanEngine e, int ms, {int stepMs = 10}) {
  for (var t = 0; t < ms; t += stepMs) {
    e.scan(elapsed: Duration(milliseconds: stepMs));
  }
}

Rung timerRung(TimerInstruction t) => Rung([Xic('I:0/0'), t]);

void main() {
  group('TON', () {
    test('accumulates with a 1.0 s base and finishes at the preset', () {
      final e = engineFor([timerRung(Ton('T4:0', TimeBase.second, 3))]);
      e.inputImage = 1;
      e.scan();
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [true, true, false]);
      expect(e.memory.pre(t0), 3);
      scanFor(e, 2900);
      expect(e.memory.acc(t0), 2);
      expect(bit(e, 'T4:0/DN'), isFalse);
      scanFor(e, 100);
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [true, false, true]);
      expect(e.memory.acc(t0), 3);
      scanFor(e, 5000);
      expect(e.memory.acc(t0), 3);
    });

    test('0.01 s base counts every 10 ms', () {
      final e = engineFor([timerRung(Ton('T4:0', TimeBase.centisecond, 5))]);
      e.inputImage = 1;
      scanFor(e, 30);
      expect(e.memory.acc(t0), 3);
      scanFor(e, 20);
      expect(bit(e, 'T4:0/DN'), isTrue);
    });

    test('keeps the sub-tick remainder across 7 ms scans', () {
      final e = engineFor([timerRung(Ton('T4:0', TimeBase.centisecond, 100))]);
      e.inputImage = 1;
      for (var i = 0; i < 100; i++) {
        e.scan(elapsed: const Duration(milliseconds: 7));
      }
      expect(e.memory.acc(t0), 70); // 700 ms / 10 ms
      for (var i = 0; i < 43; i++) {
        e.scan(elapsed: const Duration(milliseconds: 7));
      }
      expect(e.memory.acc(t0), 100); // 1001 ms
      expect(bit(e, 'T4:0/DN'), isTrue);
    });

    test('rung false clears the bits and ACC', () {
      final e = engineFor([timerRung(Ton('T4:0', TimeBase.centisecond, 5))]);
      e.inputImage = 1;
      scanFor(e, 100);
      e.inputImage = 0;
      e.scan();
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [false, false, false]);
      expect(e.memory.acc(t0), 0);
    });
  });

  group('TOF', () {
    test('DN follows the rung and drops after the preset time', () {
      final e = engineFor([timerRung(Tof('T4:0', TimeBase.second, 2))]);
      e.inputImage = 1;
      e.scan();
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [true, false, true]);
      e.inputImage = 0;
      e.scan(elapsed: const Duration(milliseconds: 10));
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [false, true, true]);
      scanFor(e, 1980);
      expect(e.memory.acc(t0), 1);
      expect(bit(e, 'T4:0/DN'), isTrue);
      scanFor(e, 10);
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [false, false, false]);
      expect(e.memory.acc(t0), 2);
    });

    test('rung true again resets ACC while timing', () {
      final e = engineFor([timerRung(Tof('T4:0', TimeBase.centisecond, 50))]);
      e.inputImage = 1;
      e.scan();
      e.inputImage = 0;
      scanFor(e, 200);
      expect(e.memory.acc(t0), 20);
      e.inputImage = 1;
      e.scan();
      expect(e.memory.acc(t0), 0);
      expect(bit(e, 'T4:0/TT'), isFalse);
    });
  });

  group('RTO', () {
    final rungs = [
      timerRung(Rto('T4:0', TimeBase.centisecond, 10)),
      Rung([Xic('I:0/1'), Res('T4:0')]),
    ];

    test('keeps ACC and DN when the rung goes false; RES clears it', () {
      final e = engineFor(rungs);
      e.inputImage = 1;
      scanFor(e, 50);
      e.inputImage = 0;
      scanFor(e, 100);
      expect(e.memory.acc(t0), 5);
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT')], [false, false]);
      e.inputImage = 1;
      scanFor(e, 50);
      expect(bit(e, 'T4:0/DN'), isTrue);
      e.inputImage = 0;
      e.scan();
      expect(bit(e, 'T4:0/DN'), isTrue);
      expect(e.memory.acc(t0), 10);
      e.inputImage = 2;
      e.scan();
      expect([bit(e, 'T4:0/EN'), bit(e, 'T4:0/TT'), bit(e, 'T4:0/DN')], [false, false, false]);
      expect(e.memory.acc(t0), 0);
    });
  });

  group('counters', () {
    final rungs = [
      Rung([Xic('I:0/0'), Ctu('C5:0', 3)]),
      Rung([Xic('I:0/1'), Ctd('C5:1', 3)]),
      Rung([Xic('I:0/2'), Res('C5:0')]),
    ];

    test('CTU counts false-to-true edges only; DN = ACC >= PRE', () {
      final e = engineFor(rungs);
      for (var i = 0; i < 3; i++) {
        e.inputImage = 1;
        e.scan();
        e.scan(); // held true: no extra count
        e.inputImage = 0;
        e.scan();
        expect(e.memory.acc(c0), i + 1);
      }
      expect(bit(e, 'C5:0/DN'), isTrue);
      expect(bit(e, 'C5:0/CU'), isFalse);
      e.inputImage = 1;
      e.scan();
      expect(bit(e, 'C5:0/CU'), isTrue);
      expect(e.memory.acc(c0), 4);
    });

    test('CTD counts down and sets DN while ACC >= PRE', () {
      final e = engineFor(rungs);
      const c1 = ElementAddress(BitFile.counter, 1);
      e.inputImage = 2;
      e.scan();
      expect(e.memory.acc(c1), -1);
      expect(bit(e, 'C5:1/CD'), isTrue);
      expect(bit(e, 'C5:1/DN'), isFalse);
      e.memory.setAcc(c1, 3);
      e.inputImage = 0;
      e.scan();
      expect(bit(e, 'C5:1/DN'), isTrue);
    });

    test('overflow wraps to -32768 with OV; underflow wraps to 32767 with UN', () {
      final e = engineFor(rungs);
      e.memory.setAcc(c0, 32767);
      e.inputImage = 1;
      e.scan();
      expect(e.memory.acc(c0), -32768);
      expect(bit(e, 'C5:0/OV'), isTrue);
      const c1 = ElementAddress(BitFile.counter, 1);
      e.memory.setAcc(c1, -32768);
      e.inputImage = 2;
      e.scan();
      expect(e.memory.acc(c1), 32767);
      expect(bit(e, 'C5:1/UN'), isTrue);
    });

    test('RES clears ACC and every status bit', () {
      final e = engineFor(rungs);
      e.inputImage = 1;
      e.scan();
      e.inputImage = 4;
      e.scan();
      expect(e.memory.acc(c0), 0);
      for (final b in ['CU', 'CD', 'DN', 'OV', 'UN']) {
        expect(bit(e, 'C5:0/$b'), isFalse, reason: b);
      }
    });
  });

  group('prescan and contacts', () {
    test('TON resets, TOF loads ACC=PRE, RTO and counters keep their data', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Ton('T4:0', TimeBase.second, 5)]),
        Rung([Xic('I:0/0'), Tof('T4:1', TimeBase.second, 7)]),
        Rung([Xic('I:0/0'), Rto('T4:2', TimeBase.second, 9)]),
        Rung([Xic('I:0/0'), Ctu('C5:0', 4)]),
      ]);
      e.memory.setAcc(t0, 3);
      e.memory.writeBit(BitAddress.parse('T4:0/DN'), true);
      e.memory.writeBit(BitAddress.parse('T4:1/DN'), true);
      e.memory.setAcc(const ElementAddress(BitFile.timer, 2), 6);
      e.memory.setAcc(c0, 2);
      e.prescan();
      expect(e.memory.acc(t0), 0);
      expect(bit(e, 'T4:0/DN'), isFalse);
      expect(e.memory.acc(const ElementAddress(BitFile.timer, 1)), 7);
      expect(bit(e, 'T4:1/DN'), isFalse);
      expect(e.memory.acc(const ElementAddress(BitFile.timer, 2)), 6);
      expect(e.memory.pre(const ElementAddress(BitFile.timer, 2)), 9);
      expect(e.memory.acc(c0), 2);
      expect(e.memory.pre(c0), 4);
    });

    test('T4 and C5 bit contacts and coils work in a rung', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Ton('T4:0', TimeBase.centisecond, 2)]),
        Rung([Xic('T4:0/DN'), Ote('O:0/0')]),
        Rung([Xio('T4:0/DN'), Ote('O:0/1')]),
        Rung([Xic('I:0/1'), Otl('C5:2/CU')]),
        Rung([Xic('C5:2/13'), Ote('O:0/2')]),
      ]);
      e.inputImage = 1;
      scanFor(e, 10);
      expect([e.outputImage & 7], [2]);
      scanFor(e, 10);
      expect(e.outputImage & 3, 1);
      e.inputImage = 3;
      e.scan();
      expect(bit(e, 'C5:2/CU'), isTrue);
      e.memory.writeBit(BitAddress.parse('C5:2/DN'), true);
      e.scan();
      expect(e.outputImage & 4, 4);
    });

    test('box instructions pass power through in the trace', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Ton('T4:0', TimeBase.second, 1), Ote('O:0/0')]),
      ]);
      expect(e.scan().rungs.single, [false, false, false]);
      e.inputImage = 1;
      expect(e.scan().rungs.single, [true, true, true]);
    });
  });

  group('Instruction.create', () {
    test('builds timers, counters and RES with their parameters', () {
      final t = Instruction.create('ton', 't4:2', timeBase: TimeBase.centisecond, preset: 9);
      expect(t, isA<Ton>());
      expect((t as Ton).timeBase, TimeBase.centisecond);
      expect(t.preset, 9);
      expect(t.target, 'T4:2');
      expect(Instruction.create('CTD', 'C5:1', preset: 2), isA<Ctd>());
      expect(Instruction.create('RES', 'C5:1'), isA<Res>());
      expect(Instruction.create('RES', 'T4:1'), isA<Res>());
    });

    test('rejects wrong files, bad addresses and bad presets', () {
      expect(() => Instruction.create('TON', 'C5:0'), throwsFormatException);
      expect(() => Instruction.create('CTU', 'T4:0'), throwsFormatException);
      expect(() => Instruction.create('RES', 'B3:0/0'), throwsFormatException);
      expect(() => Instruction.create('TON', 'T4:0', preset: 32768), throwsRangeError);
      expect(() => Instruction.create('CTU', 'C5:0', preset: -1), throwsRangeError);
    });
  });
}

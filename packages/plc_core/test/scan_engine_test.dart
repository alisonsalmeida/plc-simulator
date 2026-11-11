import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

bool out(ScanEngine e, int bit) => (e.outputImage >> bit) & 1 == 1;

void main() {
  test('XIC passes power when the bit is 1, XIO when it is 0', () {
    final e = engineFor([
      Rung([Xic('I:0/0'), Ote('O:0/0')]),
      Rung([Xio('I:0/0'), Ote('O:0/1')]),
    ]);
    e.scan();
    expect([out(e, 0), out(e, 1)], [false, true]);
    e.inputImage = 1;
    e.scan();
    expect([out(e, 0), out(e, 1)], [true, false]);
  });

  test('series contacts are AND, branch paths are OR', () {
    final e = engineFor([
      Rung([Xic('I:0/0'), Xic('I:0/1'), Ote('O:0/0')]),
      Rung([
        Branch([
          [Xic('I:0/0')],
          [Xic('I:0/1')],
        ]),
        Ote('O:0/1'),
      ]),
    ]);
    for (final (inputs, and, or) in [(0, false, false), (1, false, true), (2, false, true), (3, true, true)]) {
      e.inputImage = inputs;
      e.scan();
      expect([out(e, 0), out(e, 1)], [and, or], reason: 'inputs=$inputs');
    }
  });

  test('start/stop with seal-in keeps the motor on after the start button is released', () {
    final e = engineFor([
      Rung([
        Branch([
          [Xic('I:0/0')],
          [Xic('O:0/0')],
        ]),
        Xio('I:0/1'),
        Ote('O:0/0'),
      ]),
    ]);
    e.inputImage = 0x1; // press start
    e.scan();
    e.inputImage = 0x0; // release
    e.scan();
    expect(out(e, 0), isTrue);
    e.inputImage = 0x2; // press stop
    e.scan();
    expect(out(e, 0), isFalse);
    e.inputImage = 0x0;
    e.scan();
    expect(out(e, 0), isFalse);
  });

  test('OTL/OTU are retentive and survive prescan; OTE is cleared by prescan', () {
    final e = engineFor([
      Rung([Xic('I:0/0'), Otl('O:0/0')]),
      Rung([Xic('I:0/1'), Otu('O:0/0')]),
      Rung([Xic('I:0/2'), Ote('O:0/1')]),
    ]);
    e.inputImage = 0x5;
    e.scan();
    e.inputImage = 0x0;
    e.scan();
    expect([out(e, 0), out(e, 1)], [true, false]);
    e.inputImage = 0x4;
    e.scan();
    e
      ..stop()
      ..prescan()
      ..inputImage = 0;
    expect(e.outputImage, 0);
    e.scan();
    expect([out(e, 0), out(e, 1)], [true, false]);
    e.inputImage = 0x2;
    e.scan();
    expect(out(e, 0), isFalse);
  });

  test('outputs inside branches are evaluated on every path', () {
    final e = engineFor([
      Rung([
        Xic('I:0/0'),
        Branch([
          [Ote('O:0/0')],
          [Ote('B3/17')],
        ]),
      ]),
    ]);
    e.inputImage = 1;
    e.scan();
    expect(out(e, 0), isTrue);
    expect(e.memory.readBit(BitAddress.parse('B3:1/1')), isTrue);
  });

  test('first scan bit is set only on the first scan after prescan', () {
    final e = engineFor([
      Rung([Xic('S:1/15'), Otl('B3:0/0')]),
    ]);
    e.scan();
    expect(e.memory.readBit(firstScanBit), isTrue);
    e.scan();
    expect(e.memory.readBit(firstScanBit), isFalse);
    expect(e.memory.readBit(BitAddress.parse('B3:0/0')), isTrue);
  });

  test('trace lists the power out of each instruction in traversal order', () {
    final e = engineFor([
      Rung([
        Branch([
          [Xic('I:0/0')],
          [Xic('I:0/1')],
        ]),
        Xio('I:0/2'),
        Ote('O:0/0'),
      ]),
    ]);
    e.inputImage = 0x2;
    expect(e.scan().rungs.single, [false, true, true, true]);
  });

  group('file batch instructions', () {
    const r0 = ElementAddress(BitFile.control, 0);
    int n7(ScanEngine e, int i) => e.memory.readWord(WordAddress(BitFile.integer, i));
    void setN7(ScanEngine e, int i, int v) => e.memory.writeWord(WordAddress(BitFile.integer, i), v);
    double f8(ScanEngine e, int i) => e.memory.readFloat(WordAddress(BitFile.float, i));
    bool ctl(ScanEngine e, int b) => e.memory.readBit(r0.bitAt(b));

    test('COP copies a word array while the rung is true', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('COP', 'N7:10', source: '#N7:0', preset: 3)]),
      ]);
      for (var i = 0; i < 3; i++) {
        setN7(e, i, 10 * (i + 1));
      }
      e.scan();
      expect([n7(e, 10), n7(e, 11), n7(e, 12)], [0, 0, 0]);
      e.inputImage = 1;
      e.scan();
      expect([n7(e, 10), n7(e, 11), n7(e, 12)], [10, 20, 30]);
    });

    test('COP copies a float array', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('COP', 'F8:4', source: 'F8:0', preset: 2)]),
      ]);
      e.memory.writeFloat(const WordAddress(BitFile.float, 0), 1.5);
      e.memory.writeFloat(const WordAddress(BitFile.float, 1), -2.25);
      e.inputImage = 1;
      e.scan();
      expect([f8(e, 4), f8(e, 5)], [1.5, -2.25]);
    });

    test('FLL fills with a constant and with a word address', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('FLL', 'N7:0', source: '7', preset: 3)]),
        Rung([Xic('I:0/0'), Instruction.create('FLL', 'N7:10', source: 'N7:0', preset: 2)]),
        Rung([Xic('I:0/0'), Instruction.create('FLL', 'F8:0', source: '2.5', preset: 2)]),
      ]);
      e.inputImage = 1;
      e.scan();
      expect([n7(e, 0), n7(e, 1), n7(e, 2), n7(e, 3)], [7, 7, 7, 0]);
      expect([n7(e, 10), n7(e, 11), n7(e, 12)], [7, 7, 0]);
      expect([f8(e, 0), f8(e, 1)], [2.5, 2.5]);
    });

    test('AVE averages an integer array and sets EN, DN, POS and LEN', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('AVE', 'N7:0', source: 'N7:9', offset: 'R6:0', preset: 3)]),
      ]);
      setN7(e, 0, 10);
      setN7(e, 1, 20);
      setN7(e, 2, 33);
      e.inputImage = 1;
      e.scan();
      expect(n7(e, 9), 21);
      expect([ctl(e, ControlBit.en), ctl(e, ControlBit.dn), ctl(e, ControlBit.er)], [true, true, false]);
      expect([e.memory.pos(r0), e.memory.len(r0)], [3, 3]);
      // Runs once per rising edge.
      setN7(e, 0, 100);
      e.scan();
      expect(n7(e, 9), 21);
      e.inputImage = 0;
      e.scan();
      expect(ctl(e, ControlBit.en), isFalse);
    });

    test('AVE averages a float array into a float', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('AVE', 'F8:0', source: 'F8:8', offset: 'R6:0', preset: 2)]),
      ]);
      e.memory.writeFloat(const WordAddress(BitFile.float, 0), 1.0);
      e.memory.writeFloat(const WordAddress(BitFile.float, 1), 2.0);
      e.inputImage = 1;
      e.scan();
      expect(f8(e, 8), 1.5);
    });

    test('SRT sorts an integer array in place and sets EN, DN, POS and LEN', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Instruction.create('SRT', 'N7:0', offset: 'R6:0', preset: 3)]),
      ]);
      setN7(e, 0, 50);
      setN7(e, 1, 10);
      setN7(e, 2, 30);
      setN7(e, 3, 5);
      e.inputImage = 1;
      e.scan();
      expect([n7(e, 0), n7(e, 1), n7(e, 2), n7(e, 3)], [10, 30, 50, 5]);
      expect([ctl(e, ControlBit.en), ctl(e, ControlBit.dn)], [true, true]);
      expect([e.memory.pos(r0), e.memory.len(r0)], [3, 3]);
    });

    test('rejects a bad length or a file out of range', () {
      expect(() => Instruction.create('COP', 'N7:0', source: 'N7:10', preset: 0), throwsRangeError);
      expect(() => Instruction.create('COP', 'N7:0', source: 'N7:10', preset: 129), throwsRangeError);
      expect(() => Instruction.create('FLL', 'N7:250', source: '1', preset: 10), throwsFormatException);
      expect(() => Instruction.create('SRT', 'N7:0', offset: 'T4:0', preset: 2), throwsFormatException);
    });
  });

  group('program flow', () {
    test('JMP skips the rungs up to its LBL only when true', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Jmp(1)]),
        Rung([Xic('I:0/1'), Ote('O:0/0')]),
        Rung([Lbl(1), Xic('I:0/1'), Ote('O:0/1')]),
      ]);
      e.inputImage = 3;
      e.scan();
      expect([out(e, 0), out(e, 1)], [false, true]);
      e.inputImage = 2;
      e.scan();
      expect([out(e, 0), out(e, 1)], [true, true]);
    });

    test('a jump to a missing label is ignored', () {
      final e = engineFor([
        Rung([Jmp(9)]),
        Rung([Ote('O:0/0')]),
      ]);
      e.scan();
      expect(out(e, 0), isTrue);
    });

    test('MCR de-energizes the zone when false and closing it restores execution', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Mcr()]),
        Rung([Xic('I:0/1'), Ote('O:0/0')]),
        Rung([Xic('I:0/1'), Otl('O:0/1')]),
        Rung([Mcr()]),
        Rung([Xic('I:0/1'), Ote('O:0/2')]),
      ]);
      e.inputImage = 2;
      e.scan();
      expect([out(e, 0), out(e, 1), out(e, 2)], [false, false, true]);
      e.inputImage = 3;
      e.scan();
      expect([out(e, 0), out(e, 1), out(e, 2)], [true, true, true]);
      e.inputImage = 0;
      e.scan();
      expect(out(e, 0), isFalse);
      e.inputImage = 2;
      e.scan();
      expect([out(e, 0), out(e, 1)], [false, true], reason: 'OTL is retentive');
    });

    test('TND ends the scan when true', () {
      final e = engineFor([
        Rung([Ote('O:0/0')]),
        Rung([Xic('I:0/0'), Tnd()]),
        Rung([Ote('O:0/1')]),
      ]);
      e.scan();
      expect([out(e, 0), out(e, 1)], [true, true]);
      final f = ScanEngine(Program([
        Rung([Ote('O:0/0')]),
        Rung([Tnd()]),
        Rung([Ote('O:0/1')]),
      ]))
        ..prescan();
      final trace = f.scan();
      expect(out(f, 0), isTrue);
      expect(out(f, 1), isFalse, reason: 'rungs after TND did not run');
      expect(trace.rungs.length, 3);
    });

    test('JSR runs the subroutine and RET returns early', () {
      final program = Program(
        [
          Rung([Xic('I:0/0'), Jsr(3)]),
          Rung([Ote('O:0/3')]),
        ],
        subroutines: {
          3: [
            Rung([Sbr(3)]),
            Rung([Ote('O:0/0')]),
            Rung([Xic('I:0/1'), Ret()]),
            Rung([Ote('O:0/1')]),
          ],
        },
      );
      final e = ScanEngine(program)..prescan();
      e.scan();
      expect([out(e, 0), out(e, 3)], [false, true]);
      e.inputImage = 1;
      final trace = e.scan();
      expect([out(e, 0), out(e, 1), out(e, 3)], [true, true, true]);
      expect(trace.subroutines[3]!.length, 4);
      e.inputImage = 3;
      e.scan();
      expect([out(e, 0), out(e, 1)], [true, true], reason: 'OTE not re-run after RET, bit kept');
      e.memory.writeBit(const BitAddress(BitFile.output, 0, 1), false);
      e.scan();
      expect(out(e, 1), isFalse);
    });

    test('nested JSR calls work and recursion is bounded', () {
      final program = Program(
        [
          Rung([Jsr(3)]),
        ],
        subroutines: {
          3: [
            Rung([Ote('O:0/0')]),
            Rung([Jsr(4)]),
          ],
          4: [
            Rung([Ote('O:0/1')]),
            Rung([Jsr(4)]),
          ],
        },
      );
      final e = ScanEngine(program)..prescan();
      e.scan();
      expect([out(e, 0), out(e, 1)], [true, true]);
    });
  });
}

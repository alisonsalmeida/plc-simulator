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
}

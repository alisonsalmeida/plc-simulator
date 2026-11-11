import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

const i0 = BitAddress(BitFile.input, 0, 0);
const o0 = BitAddress(BitFile.output, 0, 0);

ScanEngine engine() => ScanEngine(
  Program([
    Rung([Xic('I:0/0'), Ote('O:0/0')]),
  ]),
);

void main() {
  test('input force overrides the physical input', () {
    final e = engine()..setForce(i0, true);
    e.scan();
    expect(e.outputImage & 1, 1);
    e.setForce(i0, false);
    e.inputImage = 1;
    e.scan();
    expect(e.outputImage & 1, 0);
  });

  test('output force overrides the ladder result', () {
    final e = engine()..setForce(o0, true);
    e.scan();
    expect(e.outputImage & 1, 1);
    e.setForce(o0, false);
    e.inputImage = 1;
    e.scan();
    expect(e.outputImage & 1, 0);
  });

  test('setForce writes to memory at once; null removes the force', () {
    final e = engine()..setForce(o0, true);
    expect(e.memory.readBit(o0), isTrue);
    e.setForce(o0, null);
    expect(e.forces, isEmpty);
    e.scan();
    expect(e.outputImage & 1, 0);
  });

  test('clearAllForces restores normal operation', () {
    final e = engine()
      ..setForce(i0, true)
      ..setForce(o0, false)
      ..clearAllForces();
    expect(e.forces, isEmpty);
    e.scan();
    expect(e.outputImage & 1, 0);
    e.inputImage = 1;
    e.scan();
    expect(e.outputImage & 1, 1);
  });
}

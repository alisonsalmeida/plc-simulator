import 'package:flutter_test/flutter_test.dart';
import 'package:plc_simulator/models/radix.model.dart';

void main() {
  test('formats signed words in each base', () {
    expect(Radix.decimal.format(-1), '-1');
    expect(Radix.hex.format(-1), 'FFFF');
    expect(Radix.hex.format(15), '000F');
    expect(Radix.binary.format(5), '0000000000000101');
  });

  test('parses valid text and rejects the rest', () {
    expect(Radix.decimal.parse(' 100 '), 100);
    expect(Radix.decimal.parse('32768'), isNull);
    expect(Radix.decimal.parse('-32768'), -32768);
    expect(Radix.hex.parse('FFFF'), -1);
    expect(Radix.hex.parse('0x0F'), 15);
    expect(Radix.hex.parse('0Fh'), 15);
    expect(Radix.hex.parse('12345'), isNull);
    expect(Radix.binary.parse('101'), 5);
    expect(Radix.binary.parse('102'), isNull);
    expect(Radix.binary.parse('11111111111111111'), isNull);
  });
}

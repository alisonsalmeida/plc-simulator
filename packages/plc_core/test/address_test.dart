import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses I/O, status and B3 addresses', () {
    expect(BitAddress.parse('I:0/0'), const BitAddress(BitFile.input, 0, 0));
    expect(BitAddress.parse('o:0/15'), const BitAddress(BitFile.output, 0, 15));
    expect(BitAddress.parse('S:1/15'), firstScanBit);
    expect(BitAddress.parse('B3:2/3'), const BitAddress(BitFile.bit, 2, 3));
    expect(BitAddress.parse('B3/17'), const BitAddress(BitFile.bit, 1, 1));
  });

  test('canonical text', () {
    expect(BitAddress.parse('B3/17').toString(), 'B3:1/1');
    expect(BitAddress.parse(' i:0/7 ').toString(), 'I:0/7');
  });

  test('rejects invalid or out-of-range addresses', () {
    for (final bad in ['', 'I0/0', 'I:1/0', 'O:0/16', 'S:2/0', 'B3:16/0', 'B3/256', 'N7:0']) {
      expect(() => BitAddress.parse(bad), throwsFormatException, reason: bad);
    }
  });
}

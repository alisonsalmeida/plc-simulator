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
    for (final bad in ['', 'I0/0', 'O:0/16', 'S:6/0', 'B3:16/0', 'B3/256', 'N7:0']) {
      expect(() => BitAddress.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('timer and counter bit addresses accept mnemonics and numbers', () {
    expect(BitAddress.parse('T4:0/DN'), const BitAddress(BitFile.timer, 0, 13));
    expect(BitAddress.parse('T4:0/13'), BitAddress.parse('T4:0/DN'));
    expect(BitAddress.parse('t4:3/en').toString(), 'T4:3/EN');
    expect(BitAddress.parse('T4:3/14').toString(), 'T4:3/TT');
    expect(BitAddress.parse('C5:3/CU').toString(), 'C5:3/CU');
    expect(BitAddress.parse('C5:15/11').toString(), 'C5:15/UN');
    expect(BitAddress.parse('T4:0/0').toString(), 'T4:0/0');
  });

  test('rejects out-of-range element and unknown timer bit', () {
    for (final bad in ['T4:16/DN', 'T4:0/XX', 'T4:0/16', 'C5:16/CU', 'T4:0', 'T4/DN']) {
      expect(() => BitAddress.parse(bad), throwsFormatException, reason: bad);
    }
  });

  test('element addresses', () {
    expect(ElementAddress.parse('t4:15').toString(), 'T4:15');
    expect(ElementAddress.parse('C5:0').file, BitFile.counter);
    expect(() => ElementAddress.parse('T4:16'), throwsFormatException);
    expect(() => ElementAddress.parse('B3:0'), throwsFormatException);
    expect(() => ElementAddress.parse('C5:0', only: BitFile.timer), throwsFormatException);
    expect(() => ElementAddress.parse('T4:0/DN'), throwsFormatException);
  });
}

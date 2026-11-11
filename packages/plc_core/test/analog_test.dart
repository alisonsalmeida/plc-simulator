import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

void main() {
  group('addresses', () {
    test('parse analog words and bits', () {
      expect(WordAddress.parse('I:1.0'), const WordAddress(BitFile.input, 1));
      expect(WordAddress.parse('i:1.3').index, 4);
      expect(WordAddress.parse('O:2.1'), const WordAddress(BitFile.output, 2));
      expect(WordAddress.parse('I:0'), const WordAddress(BitFile.input, 0));
      expect(BitAddress.parse('I:1.0/3'), const BitAddress(BitFile.input, 1, 3));
      expect(BitAddress.parse('O:2.1/15'), const BitAddress(BitFile.output, 2, 15));
    });

    test('canonical text round-trips', () {
      expect(WordAddress.parse('I:1.2').toString(), 'I:1.2');
      expect(BitAddress.parse('o:2.0/7').toString(), 'O:2.0/7');
      expect(canonicalAddress('I:1.1'), 'I:1.1');
      expect(Operand.parse('O:2.1'), WordAddress.parse('O:2.1'));
    });

    test('rejects wrong slot or channel', () {
      for (final bad in ['I:1.8', 'I:99.0', 'O:99.0', 'I:0.0', 'O:0.0']) {
        expect(() => WordAddress.parse(bad), throwsFormatException, reason: bad);
      }
      for (final bad in ['I:1.8/0', 'O:99.0/0', 'I:99/0', 'O:99/0', 'I:1.0/16']) {
        expect(() => BitAddress.parse(bad), throwsFormatException, reason: bad);
      }
    });
  });

  group('conversions', () {
    test('input 0-10 V', () {
      expect(AnalogInput.toRaw(AnalogRange.voltage, 0), 0);
      expect(AnalogInput.toRaw(AnalogRange.voltage, 10), 32767);
      expect(AnalogInput.toRaw(AnalogRange.voltage, 5), 16384);
      expect(AnalogInput.toPhysical(AnalogRange.voltage, 32767), closeTo(10, 1e-9));
    });

    test('input 4-20 mA', () {
      expect(AnalogInput.toRaw(AnalogRange.current, 0), 0);
      expect(AnalogInput.toRaw(AnalogRange.current, 4), 3277);
      expect(AnalogInput.toRaw(AnalogRange.current, 20), 16384);
      expect(AnalogInput.toRaw(AnalogRange.current, 12), closeTo(9830, 1));
      expect(AnalogInput.toPhysical(AnalogRange.current, 3277), closeTo(4, 1e-9));
      expect(AnalogInput.toPhysical(AnalogRange.current, 16384), closeTo(20, 1e-9));
      expect(AnalogInput.toPhysical(AnalogRange.current, 0), 0);
    });

    test('output ranges', () {
      expect(AnalogOutput.toPhysical(AnalogRange.voltage, 32764), closeTo(10, 1e-9));
      expect(AnalogOutput.toPhysical(AnalogRange.voltage, 0), 0);
      expect(AnalogOutput.toPhysical(AnalogRange.current, 6242), closeTo(4, 1e-9));
      expect(AnalogOutput.toPhysical(AnalogRange.current, 31208), closeTo(20, 1e-9));
      expect(AnalogOutput.toPhysical(AnalogRange.current, 32764), closeTo(21, 0.01));
      expect(AnalogOutput.toPhysical(AnalogRange.current, 0), 0);
      expect(AnalogOutput.toPhysical(AnalogRange.voltage, -5), 0);
    });
  });

  group('engine', () {
    test('analog input image survives RUN scans and is not overwritten', () {
      final e = ScanEngine(Program([
        Rung([Xic('I:0/0'), Mov('I:1.0', 'N7:0')]),
        Rung([Mov('I:1.2', 'N7:2')]),
      ]))
        ..prescan();
      e.analogInputImage[0] = 9830;
      e.analogInputImage[2] = 123;
      e.inputImage = 1;
      for (var i = 0; i < 3; i++) {
        e.scan();
      }
      expect(e.memory.readWord(WordAddress.parse('N7:0')), 9830);
      expect(e.memory.readWord(WordAddress.parse('N7:2')), 123);
      expect(e.memory.readWord(WordAddress.parse('I:1.0')), 9830);
    });

    test('analog outputs follow the ladder and clear on stop; data table is kept', () {
      final e = ScanEngine(Program([
        Rung([Mov('32764', 'O:2.0')]),
        Rung([Mov('6242', 'O:2.1')]),
      ]))
        ..prescan();
      e.scan();
      expect(e.analogOutputImage, [32764, 6242]);
      e.stop();
      expect(e.analogOutputImage, [0, 0]);
      expect(e.outputImage, 0);
      expect(e.memory.readWord(WordAddress.parse('O:2.0')), 32764);
    });
  });
}

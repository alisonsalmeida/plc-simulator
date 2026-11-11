import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

int word(ScanEngine e, String a) => e.memory.readWord(WordAddress.parse(a));

void setWord(ScanEngine e, String a, int v) =>
    e.memory.writeWord(WordAddress.parse(a), v);

bool flag(ScanEngine e, BitAddress a) => e.memory.readBit(a);

void main() {
  group('TOD', () {
    test('converts 0..9999 to BCD', () {
      final e = engineFor([
        Rung([Tod('N7:0', 'N7:1')]),
      ]);
      for (final (dec, bcd) in [
        (0, 0x0),
        (9, 0x9),
        (10, 0x10),
        (1234, 0x1234),
        (9999, 0x9999),
      ]) {
        setWord(e, 'N7:0', dec);
        e.scan();
        expect(word(e, 'N7:1'), bcd.toSigned(16), reason: '$dec');
      }
      expect(flag(e, overflowBit), isFalse);
    });

    test('out of range sets overflow and trap bits and keeps dest', () {
      for (final bad in [-1, 10000]) {
        final e = engineFor([
          Rung([Tod('N7:0', 'N7:1')]),
        ]);
        setWord(e, 'N7:1', 77);
        setWord(e, 'N7:0', bad);
        e.scan();
        expect(word(e, 'N7:1'), 77, reason: '$bad');
        expect(flag(e, overflowBit), isTrue, reason: '$bad');
        expect(flag(e, overflowTrapBit), isTrue, reason: '$bad');
      }
    });

    test('does nothing while the rung is false', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Tod('N7:0', 'N7:1')]),
      ]);
      setWord(e, 'N7:0', 12);
      e.scan();
      expect(word(e, 'N7:1'), 0);
    });
  });

  group('FRD', () {
    test('converts BCD to decimal', () {
      final e = engineFor([
        Rung([Frd('N7:0', 'N7:1')]),
      ]);
      for (final (bcd, dec) in [
        (0x0, 0),
        (0x9, 9),
        (0x10, 10),
        (0x1234, 1234),
        (0x9999, 9999),
      ]) {
        setWord(e, 'N7:0', bcd.toSigned(16));
        e.scan();
        expect(word(e, 'N7:1'), dec, reason: '$bcd');
      }
      expect(flag(e, overflowBit), isFalse);
    });

    test('any nibble above 9 sets overflow and trap bits and keeps dest', () {
      for (final bad in [0xA, 0x00B0, 0x0C00, 0xF000]) {
        final e = engineFor([
          Rung([Frd('N7:0', 'N7:1')]),
        ]);
        setWord(e, 'N7:1', 55);
        setWord(e, 'N7:0', bad.toSigned(16));
        e.scan();
        expect(word(e, 'N7:1'), 55, reason: '$bad');
        expect(flag(e, overflowBit), isTrue, reason: '$bad');
        expect(flag(e, overflowTrapBit), isTrue, reason: '$bad');
      }
    });

    test('round trip TOD then FRD', () {
      final e = engineFor([
        Rung([Tod('N7:0', 'N7:1')]),
        Rung([Frd('N7:1', 'N7:2')]),
      ]);
      for (final v in [0, 7, 42, 999, 5678, 9999]) {
        setWord(e, 'N7:0', v);
        e.scan();
        expect(word(e, 'N7:2'), v);
      }
    });
  });

  test('JSON round trip keeps TOD and FRD', () {
    final program = Program([
      Rung([Tod('N7:0', 'N7:1')]),
      Rung([Frd('I:0', 'N7:2')]),
    ]);
    final copy = programFromJson(programToJson(program));
    expect(copy.rungs[0].elements.single, isA<Tod>());
    expect(copy.rungs[1].elements.single, isA<Frd>());
    expect(programToJson(copy), programToJson(program));
  });
}

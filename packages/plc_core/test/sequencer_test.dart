import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

const r0 = ElementAddress(BitFile.control, 0);

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

int n7(ScanEngine e, int i) => e.memory.readWord(WordAddress(BitFile.integer, i));

void setN7(ScanEngine e, int i, int v) =>
    e.memory.writeWord(WordAddress(BitFile.integer, i), v);

/// One false-to-true-to-false pulse of I:0/0.
void pulse(ScanEngine e) {
  e.inputImage |= 1;
  e.scan();
  e.inputImage &= ~1;
  e.scan();
}

Sqo sqo({String mask = '0xFFFF', int length = 3}) => Sqo(
      file: 'N7:10',
      mask: mask,
      dest: 'N7:0',
      control: 'R6:0',
      length: length,
    );

void main() {
  group('SQO', () {
    ScanEngine engine({String mask = '0xFFFF'}) {
      final e = engineFor([Rung([Xic('I:0/0'), sqo(mask: mask)])]);
      setN7(e, 11, 0x0001);
      setN7(e, 12, 0x0002);
      setN7(e, 13, 0x0004);
      return e;
    }

    test('steps through the file and wraps from length back to 1', () {
      final e = engine();
      final seen = <int>[];
      for (var i = 0; i < 4; i++) {
        pulse(e);
        seen.add(n7(e, 0));
      }
      expect(seen, [1, 2, 4, 1]);
      expect(e.memory.pos(r0), 1);
      expect(e.memory.len(r0), 3);
    });

    test('does not advance while the rung stays true', () {
      final e = engine();
      e.inputImage = 1;
      e.scan();
      e.scan();
      expect(e.memory.pos(r0), 1);
      expect(bit(e, 'R6:0/EN'), isTrue);
      e.inputImage = 0;
      e.scan();
      expect(bit(e, 'R6:0/EN'), isFalse);
    });

    test('DN is set only at the last step', () {
      final e = engine();
      pulse(e);
      pulse(e);
      expect(bit(e, 'R6:0/DN'), isFalse);
      pulse(e);
      expect(e.memory.pos(r0), 3);
      expect(bit(e, 'R6:0/DN'), isTrue);
      pulse(e); // wraps to step 1
      expect(bit(e, 'R6:0/DN'), isFalse);
    });

    test('mask keeps the unmasked bits of the destination', () {
      final e = engine(mask: '0x00FF');
      setN7(e, 0, 0x1200);
      setN7(e, 11, 0x5634);
      pulse(e);
      expect(n7(e, 0), 0x1234);
    });

    test('negative file words are masked as unsigned', () {
      final e = engine();
      setN7(e, 11, -1);
      pulse(e);
      expect(n7(e, 0), -1);
    });
  });

  group('SQC', () {
    ScanEngine engine({String mask = '0xFFFF'}) {
      final e = engineFor([
        Rung([
          Xic('I:0/0'),
          Sqc(file: 'N7:10', mask: mask, source: 'N7:0', control: 'R6:0', length: 3),
        ]),
      ]);
      setN7(e, 11, 0x0010);
      setN7(e, 12, 0x0020);
      setN7(e, 13, 0x0030);
      return e;
    }

    test('sets and clears FD according to the comparison', () {
      final e = engine();
      setN7(e, 0, 0x0010);
      pulse(e); // step 1 matches
      expect(bit(e, 'R6:0/FD'), isTrue);
      pulse(e); // step 2 differs
      expect(bit(e, 'R6:0/FD'), isFalse);
      setN7(e, 0, 0x0030);
      pulse(e); // step 3 matches
      expect(bit(e, 'R6:0/FD'), isTrue);
    });

    test('FD is bit 8 of the control word', () {
      expect(ControlBit.fd, 8);
      final e = engine();
      setN7(e, 0, 0x0010);
      pulse(e);
      expect(e.memory.readBit(r0.bitAt(8)), isTrue);
    });

    test('mask ignores the unmasked bits in the comparison', () {
      final e = engine(mask: '0x00F0');
      setN7(e, 0, 0xFF1F);
      pulse(e);
      expect(bit(e, 'R6:0/FD'), isTrue);
    });

    test('DN at the last step and wrap to 1', () {
      final e = engine();
      pulse(e);
      pulse(e);
      expect(bit(e, 'R6:0/DN'), isFalse);
      pulse(e);
      expect(bit(e, 'R6:0/DN'), isTrue);
      pulse(e);
      expect(e.memory.pos(r0), 1);
      expect(bit(e, 'R6:0/DN'), isFalse);
    });

    test('accepts a constant source', () {
      final e = engineFor([
        Rung([
          Xic('I:0/0'),
          Sqc(file: 'N7:10', mask: '0xFFFF', source: '16', control: 'R6:0', length: 2),
        ]),
      ]);
      setN7(e, 11, 16);
      pulse(e);
      expect(bit(e, 'R6:0/FD'), isTrue);
    });
  });

  group('SQL', () {
    test('loads the source into successive words and wraps', () {
      final e = engineFor([
        Rung([
          Xic('I:0/0'),
          Sql(file: 'N7:10', source: 'N7:0', control: 'R6:0', length: 2),
        ]),
      ]);
      setN7(e, 0, 100);
      pulse(e);
      expect(n7(e, 11), 100);
      expect(n7(e, 12), 0);
      expect(bit(e, 'R6:0/DN'), isFalse);
      setN7(e, 0, 200);
      pulse(e);
      expect(n7(e, 12), 200);
      expect(e.memory.pos(r0), 2);
      expect(bit(e, 'R6:0/DN'), isTrue);
      setN7(e, 0, 300);
      pulse(e); // wraps to step 1
      expect(n7(e, 11), 300);
      expect(n7(e, 10), 0); // step 0 is never written
      expect(bit(e, 'R6:0/DN'), isFalse);
    });

    test('loads a constant into B3', () {
      final e = engineFor([
        Rung([
          Xic('I:0/0'),
          Sql(file: 'B3:0', source: '7', control: 'R6:1', length: 1),
        ]),
      ]);
      pulse(e);
      expect(e.memory.word(BitFile.bit, 1), 7);
    });
  });

  group('creation and validation', () {
    test('Instruction.create builds the three sequencers', () {
      final a = Instruction.create('SQO', 'N7:10',
          mask: '00FFh', source: 'N7:0', offset: 'R6:0', preset: 4);
      expect(a, isA<Sqo>());
      expect((a as Sqo).dest, WordAddress.parse('N7:0'));
      expect(a.mask, const Constant(255));
      final b = Instruction.create('sqc', 'B3:1',
          mask: '0xFFFF', source: '5', offset: 'R6:2', preset: 4);
      expect(b, isA<Sqc>());
      expect(b.target, 'B3:1');
      final c = Instruction.create('SQL', 'N7:3', source: 'N7:1', offset: 'R6:1', preset: 4);
      expect(c, isA<Sql>());
      expect((c as Sql).word(2), WordAddress.parse('N7:5'));
      expect(c.isOutput, isTrue);
    });

    test('rejects a bad length, file, control and operand', () {
      expect(() => sqo(length: 0), throwsA(isA<ArgumentError>()));
      expect(() => sqo(length: 129), throwsA(isA<ArgumentError>()));
      expect(
        () => Sql(file: 'T4:0.ACC', source: '1', control: 'R6:0', length: 1),
        throwsFormatException,
      );
      expect(
        () => Sql(file: 'I:0', source: '1', control: 'R6:0', length: 1),
        throwsFormatException,
      );
      expect(
        () => Sql(file: 'N7:0', source: '1', control: 'T4:0', length: 1),
        throwsFormatException,
      );
      expect(
        () => Sql(file: 'N7:0', source: 'foo', control: 'R6:0', length: 1),
        throwsFormatException,
      );
      expect(
        () => Sqo(file: 'N7:0', mask: '1', dest: '5', control: 'R6:0', length: 1),
        throwsFormatException,
      );
    });

    test('rejects a file that does not fit in the data file', () {
      // N7 has 32 words: steps 1..length live at N7:(start + 1..length).
      expect(() => Sql(file: 'N7:31', source: '1', control: 'R6:0', length: 1),
          throwsFormatException);
      expect(() => Sql(file: 'N7:0', source: '1', control: 'R6:0', length: 32),
          throwsFormatException);
      expect(Sql(file: 'N7:0', source: '1', control: 'R6:0', length: 31).length, 31);
      expect(() => Sql(file: 'B3:15', source: '1', control: 'R6:0', length: 1),
          throwsFormatException);
    });

    test('JSON round trip keeps every field', () {
      final program = Program([
        Rung([
          Xic('I:0/0'),
          Sqo(file: 'N7:10', mask: '255', dest: 'N7:0', control: 'R6:0', length: 3),
          Sqc(file: 'N7:10', mask: '255', source: 'N7:1', control: 'R6:1', length: 3),
          Sql(file: 'B3:0', source: '9', control: 'R6:2', length: 5),
        ]),
      ]);
      final back = programFromJson(programToJson(program));
      final els = back.rungs.single.elements;
      expect(els[1], isA<Sqo>());
      expect((els[1] as Sqo).dest.toString(), 'N7:0');
      expect((els[1] as Sqo).control.toString(), 'R6:0');
      expect((els[2] as Sqc).source.toString(), 'N7:1');
      expect((els[2] as Sqc).mask, const Constant(255));
      expect((els[3] as Sql).length, 5);
      expect((els[3] as Sql).file.toString(), 'B3:0');
      expect(programToJson(back), programToJson(program));
    });
  });
}

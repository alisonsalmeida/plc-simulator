import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

const r0 = ElementAddress(BitFile.control, 0);

ScanEngine engineFor(List<Rung> rungs) => ScanEngine(Program(rungs))..prescan();

bool bit(ScanEngine e, String a) => e.memory.readBit(BitAddress.parse(a));

int n7(ScanEngine e, int i) =>
    e.memory.readWord(WordAddress(BitFile.integer, i));

void setN7(ScanEngine e, int i, int v) =>
    e.memory.writeWord(WordAddress(BitFile.integer, i), v);

/// One false-to-true-to-false pulse of I:0/0.
void pulse(ScanEngine e) {
  e.inputImage |= 1;
  e.scan();
  e.inputImage &= ~1;
  e.scan();
}

void main() {
  group('R6 addressing', () {
    test('parses R6 bits, words and elements', () {
      expect(BitAddress.parse('R6:2/DN').toString(), 'R6:2/DN');
      expect(BitAddress.parse('R6:0/10').toString(), 'R6:0/UL');
      expect(WordAddress.parse('R6:1.LEN').toString(), 'R6:1.LEN');
      expect(WordAddress.parse('r6:1.pos').toString(), 'R6:1.POS');
      expect(WordAddress.parse('R6:1.PRE'), WordAddress.parse('R6:1.LEN'));
      expect(ElementAddress.parse('R6:3').statusIndex, 9);
      expect(() => WordAddress.parse('T4:0.LEN'), throwsFormatException);
      expect(canonicalAddress('R6:4'), 'R6:4');
    });

    test('len and pos use words 1 and 2 of the element', () {
      final m = PlcMemory()
        ..setLen(const ElementAddress(BitFile.control, 1), 7)
        ..setPos(const ElementAddress(BitFile.control, 1), 3);
      expect(m.word(BitFile.control, 4), 7);
      expect(m.word(BitFile.control, 5), 3);
      expect(m.len(const ElementAddress(BitFile.control, 1)), 7);
      expect(m.pos(const ElementAddress(BitFile.control, 1)), 3);
    });
  });

  group('BSL', () {
    Rung rung() => Rung([Xic('I:0/0'), Bsl('B3:0', 'I:0/1', 'R6:0', 4)]);

    test('shifts left on the rising edge only and sets EN / DN', () {
      final e = engineFor([rung()]);
      e.inputImage = 0x3; // enable + data bit
      e.scan();
      expect(e.memory.word(BitFile.bit, 0), 1);
      expect([bit(e, 'R6:0/EN'), bit(e, 'R6:0/DN')], [true, true]);
      expect(e.memory.len(r0), 4);
      e.scan(); // still true: no second shift
      expect(e.memory.word(BitFile.bit, 0), 1);
      e.inputImage = 0; // falls: EN / DN cleared
      e.scan();
      expect([bit(e, 'R6:0/EN'), bit(e, 'R6:0/DN')], [false, false]);
      e.inputImage = 1; // data bit 0
      e.scan();
      expect(e.memory.word(BitFile.bit, 0), 2);
    });

    test(
      'the bit shifted out of the last position goes to UL; bits beyond length stay',
      () {
        final e = engineFor([rung()]);
        e.memory.setWord(BitFile.bit, 0, 0x18); // bits 3 and 4
        pulse(e);
        expect(
          e.memory.word(BitFile.bit, 0),
          0x10 | 0x00,
        ); // bit 3 -> UL, bit 4 untouched, bit 0 = 0
        expect(bit(e, 'R6:0/UL'), isTrue);
        pulse(e);
        expect(e.memory.word(BitFile.bit, 0), 0x10);
        expect(bit(e, 'R6:0/UL'), isFalse);
      },
    );
  });

  group('BSR', () {
    test('shifts right, bit 0 goes to UL, new bit enters at length - 1', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Bsr('B3:0', 'I:0/1', 'R6:0', 4)]),
      ]);
      e.memory.setWord(BitFile.bit, 0, 0x5); // bits 0 and 2
      e.inputImage = 0x3;
      e.scan();
      expect(e.memory.word(BitFile.bit, 0), 0x2 | 0x8);
      expect(bit(e, 'R6:0/UL'), isTrue);
      expect([bit(e, 'R6:0/EN'), bit(e, 'R6:0/DN')], [true, true]);
      e.inputImage = 0;
      e.scan();
      expect(bit(e, 'R6:0/EN'), isFalse);
    });

    test('spans more than one word', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Bsl('B3:0', 'I:0/1', 'R6:0', 20)]),
      ]);
      e.memory.setWord(BitFile.bit, 0, 0x8000);
      pulse(e);
      expect(e.memory.word(BitFile.bit, 0), 0);
      expect(e.memory.word(BitFile.bit, 1), 1);
    });
  });

  group('FIFO', () {
    List<Rung> rungs() => [
      Rung([Xic('I:0/0'), Ffl('N7:0', 'N7:20', 'R6:0', 3)]),
      Rung([Xic('I:0/1'), Ffu('N7:0', 'N7:21', 'R6:0', 3)]),
    ];

    void load(ScanEngine e, int v) {
      setN7(e, 20, v);
      e.inputImage = 1;
      e.scan();
      e.inputImage = 0;
      e.scan();
    }

    void unload(ScanEngine e) {
      e.inputImage = 2;
      e.scan();
      e.inputImage = 0;
      e.scan();
    }

    test('loads, sets DN when full and ignores loads beyond the length', () {
      final e = engineFor(rungs());
      load(e, 10);
      load(e, 20);
      expect([n7(e, 0), n7(e, 1), e.memory.pos(r0)], [10, 20, 2]);
      expect(bit(e, 'R6:0/DN'), isFalse);
      load(e, 30);
      expect(bit(e, 'R6:0/DN'), isTrue);
      load(e, 40);
      expect([n7(e, 0), n7(e, 1), n7(e, 2), e.memory.pos(r0)], [10, 20, 30, 3]);
    });

    test('unloads the oldest word, shifts the rest down and flags empty', () {
      final e = engineFor(rungs());
      load(e, 10);
      load(e, 20);
      load(e, 30);
      unload(e);
      expect(n7(e, 21), 10);
      expect([n7(e, 0), n7(e, 1), e.memory.pos(r0)], [20, 30, 2]);
      expect(bit(e, 'R6:0/DN'), isFalse);
      expect(bit(e, 'R6:0/EM'), isFalse);
      unload(e);
      unload(e);
      expect([n7(e, 21), e.memory.pos(r0), bit(e, 'R6:0/EM')], [30, 0, true]);
      setN7(e, 21, 99);
      unload(e); // empty: destination untouched
      expect([n7(e, 21), e.memory.pos(r0)], [99, 0]);
    });

    test('EN / EU follow the rung and a held rung acts once', () {
      final e = engineFor(rungs());
      setN7(e, 20, 5);
      e.inputImage = 3;
      e.scan();
      e.scan();
      expect([bit(e, 'R6:0/EN'), bit(e, 'R6:0/EU')], [true, true]);
      expect(
        e.memory.pos(r0),
        0,
      ); // load then unload of the same word in one scan
      e.inputImage = 0;
      e.scan();
      expect([bit(e, 'R6:0/EN'), bit(e, 'R6:0/EU')], [false, false]);
    });
  });

  group('LIFO', () {
    test('unloads the newest word first', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Lfl('N7:0', 'N7:20', 'R6:0', 3)]),
        Rung([Xic('I:0/1'), Lfu('N7:0', 'N7:21', 'R6:0', 3)]),
      ]);
      for (final v in [1, 2, 3]) {
        setN7(e, 20, v);
        pulse(e);
      }
      expect(bit(e, 'R6:0/DN'), isTrue);
      for (final v in [3, 2, 1]) {
        e.inputImage = 2;
        e.scan();
        e.inputImage = 0;
        e.scan();
        expect(n7(e, 21), v);
      }
      expect(
        [e.memory.pos(r0), bit(e, 'R6:0/EM'), bit(e, 'R6:0/DN')],
        [0, true, false],
      );
    });

    test('loads constants', () {
      final e = engineFor([
        Rung([Xic('I:0/0'), Lfl('N7:0', '42', 'R6:0', 2)]),
      ]);
      pulse(e);
      expect(n7(e, 0), 42);
    });
  });

  group('creation and JSON', () {
    test('rejects bad arguments', () {
      expect(() => Bsl('B3:0', 'I:0/0', 'T4:0', 8), throwsFormatException);
      expect(() => Bsl('B3:0', 'I:0/0', 'R6:0', 0), throwsRangeError);
      expect(() => Ffl('N7:31', '1', 'R6:0', 2), throwsFormatException);
      expect(() => Ffl('O:0', '1', 'R6:0', 2), throwsFormatException);
    });

    test('round-trips through JSON', () {
      final program = Program([
        Rung([
          Xic('I:0/0'),
          Bsl('B3:0', 'I:0/1', 'R6:0', 8),
          Bsr('B3:1', 'B3:0/0', 'R6:1', 8),
          Ffl('N7:0', 'N7:20', 'R6:2', 5),
          Ffu('N7:0', 'N7:21', 'R6:2', 5),
          Lfl('N7:5', '7', 'R6:3', 4),
          Lfu('N7:5', 'N7:22', 'R6:3', 4),
        ]),
      ]);
      final back = programFromJson(programToJson(program));
      final a = programToJson(program);
      expect(programToJson(back), a);
      final ins = back.rungs.first.elements;
      expect(ins[1], isA<Bsl>());
      expect((ins[3] as Ffl).length, 5);
      expect((ins[6] as Lfu).dest, WordAddress.parse('N7:22'));
    });

    test('Instruction.create builds the six mnemonics', () {
      for (final m in ['BSL', 'BSR']) {
        expect(
          Instruction.create(
            m,
            'B3:0',
            source: 'I:0/0',
            mask: 'R6:0',
            preset: 4,
          ).mnemonic,
          m,
        );
      }
      for (final m in ['FFL', 'LFL', 'FFU', 'LFU']) {
        expect(
          Instruction.create(
            m,
            'N7:0',
            source: 'N7:9',
            mask: 'R6:0',
            preset: 4,
          ).mnemonic,
          m,
        );
      }
    });
  });
}

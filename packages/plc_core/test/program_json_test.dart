import 'dart:convert';

import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

Program everyMnemonic() => Program(
  [
    Rung(
      [
        Instruction.create('XIC', 'I:0/0'),
        Branch([
          [Instruction.create('XIO', 'I:0/1')],
          [
            Instruction.create('EQU', 'N7:0', source: '5'),
            Branch([
              [Instruction.create('LIM', 'N7:2', source: '0', mask: '10')],
              [],
            ]),
          ],
        ]),
        Instruction.create('OTE', 'O:0/0'),
        Instruction.create('OTL', 'O:0/1'),
        Instruction.create('OTU', 'O:0/2'),
      ],
      title: 'Bits',
      comment: 'Line 1\nLine 2',
    ),
    Rung([
      Instruction.create(
        'TON',
        'T4:0',
        timeBase: TimeBase.centisecond,
        preset: 50,
      ),
      Instruction.create('TOF', 'T4:1', preset: 3),
      Instruction.create('RTO', 'T4:2', timeBase: TimeBase.second, preset: 7),
      Instruction.create('CTU', 'C5:0', preset: 10),
      Instruction.create('CTD', 'C5:1', preset: 2),
      Instruction.create('RES', 'C5:0'),
    ]),
    Rung([
      Instruction.create('NEQ', 'N7:0', source: 'N7:1'),
      Instruction.create('LES', 'N7:0', source: '-3'),
      Instruction.create('LEQ', 'N7:0', source: '3'),
      Instruction.create('GRT', 'N7:0', source: '3'),
      Instruction.create('GEQ', 'N7:0', source: '3'),
      Instruction.create('MOV', 'N7:3', source: 'N7:4'),
      Instruction.create('MVM', 'N7:3', source: 'I:0', mask: '00FFh'),
      Instruction.create('CLR', 'N7:5'),
      Instruction.create('ADD', 'N7:6', source: 'N7:1', mask: '2'),
      Instruction.create('SUB', 'N7:6', source: 'N7:1', mask: '2'),
      Instruction.create('MUL', 'N7:6', source: 'N7:1', mask: '2'),
      Instruction.create('DIV', 'N7:6', source: 'N7:1', mask: '2'),
      Instruction.create('NEG', 'N7:7', source: 'N7:1'),
      Instruction.create('SQR', 'N7:7', source: 'N7:1'),
      Instruction.create(
        'SCL',
        'N7:8',
        source: 'N7:1',
        mask: '5000',
        offset: '-4',
      ),
    ]),
  ],
  symbols: {'I:0/0': 'B1 Liga', 'O:0/0': 'M1'},
  descriptions: {'I:0/0': 'Botão liga\nmotor M1'},
);

void main() {
  test('round-trips the I/O mapping and defaults it when absent', () {
    const program = Program(
      [],
      ioMapping: IoMappingConfig(
        digitalInputSlot: 1,
        digitalOutputSlot: 2,
        analogInputSlot: 3,
        analogOutputSlot: 4,
        thumbwheelSlot: 5,
        sevenSegmentSlot: 6,
      ),
    );
    final json =
        jsonDecode(jsonEncode(programToJson(program))) as Map<String, Object?>;
    expect(programFromJson(json).ioMapping, program.ioMapping);
    json.remove('ioMapping');
    expect(programFromJson(json).ioMapping, const IoMappingConfig());
  });

  test('round-trips unassociated peripherals as null', () {
    const program = Program([], ioMapping: IoMappingConfig(thumbwheelSlot: 3));
    final json =
        jsonDecode(jsonEncode(programToJson(program))) as Map<String, Object?>;
    final back = programFromJson(json).ioMapping;
    expect(back.thumbwheelSlot, 3);
    expect(back.sevenSegmentSlot, isNull);
    expect(back.copyWith(clearThumbwheel: true).thumbwheelSlot, isNull);
  });

  test('round-trips every mnemonic, branches, symbols and descriptions', () {
    final json = programToJson(everyMnemonic());
    final text = jsonEncode(json);
    final back = programFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(jsonEncode(programToJson(back)), text);
    expect(back.rungs, hasLength(3));
    expect(back.rungs[0].title, 'Bits');
    expect(back.rungs[0].comment, 'Line 1\nLine 2');
    expect(back.rungs[0].elements[1], isA<Branch>());
    expect(back.symbols['I:0/0'], 'B1 Liga');
    expect(back.descriptions['I:0/0'], 'Botão liga\nmotor M1');
    final mnemonics = [
      for (final r in back.rungs.skip(1))
        for (final e in r.elements) (e as Instruction).mnemonic,
    ];
    expect(
      mnemonics,
      containsAll(['TON', 'CTD', 'RES', 'NEQ', 'MVM', 'DIV', 'SCL']),
    );
  });

  group('rejects bad input with FormatException', () {
    Map<String, Object?> valid() => programToJson(everyMnemonic());
    Map<String, Object?> withOp(Map<String, Object?> op) => {
      ...valid(),
      'rungs': [
        {
          'elements': [op],
        },
      ],
    };

    test('wrong format', () {
      expect(
        () => programFromJson({...valid(), 'format': 'other'}),
        throwsFormatException,
      );
    });
    test('wrong version', () {
      expect(
        () => programFromJson({...valid(), 'version': 2}),
        throwsFormatException,
      );
    });
    test('unknown op', () {
      expect(
        () => programFromJson(withOp({'op': 'FOO', 'address': 'I:0/0'})),
        throwsFormatException,
      );
    });
    test('bad address', () {
      expect(
        () => programFromJson(withOp({'op': 'XIC', 'address': 'Z:9'})),
        throwsFormatException,
      );
    });
    test('preset out of range', () {
      expect(
        () => programFromJson(
          withOp({'op': 'CTU', 'address': 'C5:0', 'preset': 99999}),
        ),
        throwsFormatException,
      );
    });
    test('rungs is not a list', () {
      expect(
        () => programFromJson({...valid(), 'rungs': 'x'}),
        throwsFormatException,
      );
    });
  });

  test('round-trips COP, FLL, AVE and SRT', () {
    final program = Program([
      Rung([
        Instruction.create('COP', 'N7:10', source: '#N7:0', preset: 4),
        Instruction.create('FLL', 'F8:0', source: '1.5', preset: 3),
        Instruction.create('AVE', 'N7:0', source: 'N7:9', offset: 'R6:1', preset: 5),
        Instruction.create('SRT', 'N7:20', offset: 'R6:2', preset: 6),
      ]),
    ]);
    final text = jsonEncode(programToJson(program));
    final back = programFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(jsonEncode(programToJson(back)), text);
    final ins = back.rungs.single.elements;
    expect(ins[0], isA<Cop>().having((c) => c.length, 'length', 4));
    expect(ins[1], isA<Fll>().having((f) => f.source, 'source', const FloatConstant(1.5)));
    expect(ins[2], isA<Ave>().having((a) => a.control.toString(), 'control', 'R6:1'));
    expect(ins[3], isA<Srt>().having((s) => s.target, 'target', 'N7:20'));
  });

  test('round-trips the program flow instructions and the subroutines', () {
    final program = Program(
      [
        Rung([Xic('I:0/0'), Jmp(5)]),
        Rung([Mcr()]),
        Rung([Mcr()]),
        Rung([Jsr(3), Tnd()]),
        Rung([Lbl(5)]),
      ],
      subroutines: {
        3: [
          Rung([Sbr(3)]),
          Rung([Xic('I:0/1'), Ret()]),
        ],
        4: [
          Rung([Sbr()]),
        ],
      },
    );
    final text = jsonEncode(programToJson(program));
    final back = programFromJson(jsonDecode(text) as Map<String, Object?>);
    expect(jsonEncode(programToJson(back)), text);
    expect(back.rungs[0].elements[1], isA<Jmp>().having((j) => j.label, 'label', 5));
    expect(back.rungs[3].elements, [isA<Jsr>(), isA<Tnd>()]);
    expect(back.rungs[4].elements.single, isA<Lbl>().having((l) => l.target, 'target', 'Q2:5'));
    expect(back.subroutines.keys, [3, 4]);
    expect(back.subroutines[3]![0].elements.single, isA<Sbr>().having((s) => s.subroutine, 'sub', 3));
    expect(back.subroutines[3]![1].elements.last, isA<Ret>());
    expect(back.subroutines[4]![0].elements.single, isA<Sbr>().having((s) => s.subroutine, 'sub', 0));
    expect(back.rungsFor(3), back.subroutines[3]);
    expect(back.rungsFor(2), back.rungs);
  });

  test('parses labels and subroutine files, plain or prefixed', () {
    expect(Instruction.create('JMP', 'Q2:12'), isA<Jmp>().having((j) => j.label, 'label', 12));
    expect(Instruction.create('LBL', '7'), isA<Lbl>().having((l) => l.label, 'label', 7));
    expect(Instruction.create('JSR', 'U:3'), isA<Jsr>().having((j) => j.subroutine, 'sub', 3));
    expect(Instruction.create('JSR', '4'), isA<Jsr>().having((j) => j.subroutine, 'sub', 4));
    expect(() => Instruction.create('JMP', '1000'), throwsFormatException);
    expect(() => Instruction.create('JSR', 'U:1'), throwsFormatException);
  });
}

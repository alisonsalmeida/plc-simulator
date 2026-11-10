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
}

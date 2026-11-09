import 'package:plc_core/plc_core.dart';

import '../models/ladder_example.model.dart';

/// Bundled examples for the first CLP II lessons (contacts and coils). UI text is pt-BR.
final ladderExamples = <LadderExample>[
  LadderExample(
    name: 'Partida direta com selo',
    momentaryInputs: const {0, 1},
    program: Program(
      [
        Rung(
          [
            Branch([
              [Xic('I:0/0')],
              [Xic('O:0/0')],
            ]),
            Xio('I:0/1'),
            Ote('O:0/0'),
          ],
          comment: 'Liga o motor com B1; o contato de selo mantém K1 ligado; B0 desliga.',
        ),
        Rung([Xic('O:0/0'), Ote('O:0/1')], comment: 'Sinaleiro de motor ligado.'),
        Rung([Xio('O:0/0'), Ote('O:0/2')], comment: 'Sinaleiro de motor desligado.'),
      ],
      symbols: const {
        'I:0/0': 'B1 Liga',
        'I:0/1': 'B0 Desliga',
        'O:0/0': 'K1 Motor',
        'O:0/1': 'H1 Ligado',
        'O:0/2': 'H2 Desligado',
      },
    ),
  ),
  LadderExample(
    name: 'Contatos NA e NF, E e OU',
    program: Program(
      [
        Rung([Xic('I:0/0'), Ote('O:0/0')], comment: 'Contato NA (XIC): liga quando S1 = 1.'),
        Rung([Xio('I:0/0'), Ote('O:0/1')], comment: 'Contato NF (XIO): liga quando S1 = 0.'),
        Rung([Xic('I:0/1'), Xic('I:0/2'), Ote('O:0/2')], comment: 'Contatos em série: função E.'),
        Rung(
          [
            Branch([
              [Xic('I:0/1')],
              [Xic('I:0/2')],
            ]),
            Ote('O:0/3'),
          ],
          comment: 'Contatos em paralelo: função OU.',
        ),
      ],
      symbols: const {
        'I:0/0': 'S1',
        'I:0/1': 'S2',
        'I:0/2': 'S3',
        'O:0/0': 'H1 NA',
        'O:0/1': 'H2 NF',
        'O:0/2': 'H3 E',
        'O:0/3': 'H4 OU',
      },
    ),
  ),
  LadderExample(
    name: 'Set/Reset (OTL/OTU)',
    momentaryInputs: const {0, 1},
    program: Program(
      [
        Rung([Xic('I:0/0'), Otl('O:0/0')], comment: 'OTL: B1 liga K1 e o bit fica travado.'),
        Rung([Xic('I:0/1'), Otu('O:0/0')], comment: 'OTU: B0 destrava K1.'),
      ],
      symbols: const {'I:0/0': 'B1 Liga', 'I:0/1': 'B0 Desliga', 'O:0/0': 'K1 Motor'},
    ),
  ),
];

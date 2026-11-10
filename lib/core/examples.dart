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
          title: 'PARTIDA DIRETA',
          comment: 'Liga o motor com B1; o contato de selo mantém K1 ligado.\nB0 desliga.',
        ),
        Rung(
          [Xic('O:0/0'), Ote('O:0/1')],
          title: 'SINALEIROS',
          comment: 'Sinaleiro de motor ligado.',
        ),
        Rung([Xio('O:0/0'), Ote('O:0/2')], comment: 'Sinaleiro de motor desligado.'),
      ],
      symbols: const {
        'I:0/0': 'B1_LIGA',
        'I:0/1': 'B0_DESLIGA',
        'O:0/0': 'K1_MOTOR',
        'O:0/1': 'H1_LIGADO',
        'O:0/2': 'H2_DESLIGADO',
      },
      descriptions: const {
        'I:0/0': 'Botão liga\nmotor M1',
        'I:0/1': 'Botão desliga\nmotor M1 (NF)',
        'O:0/0': 'Contator do\nmotor M1',
        'O:0/1': 'Lâmpada\nmotor ligado',
        'O:0/2': 'Lâmpada\nmotor desligado',
      },
    ),
  ),
  LadderExample(
    name: 'Contatos NA e NF, E e OU',
    program: Program(
      [
        Rung(
          [Xic('I:0/0'), Ote('O:0/0')],
          title: 'CONTATOS NA E NF',
          comment: 'Contato NA (XIC): liga quando S1 = 1.',
        ),
        Rung([Xio('I:0/0'), Ote('O:0/1')], comment: 'Contato NF (XIO): liga quando S1 = 0.'),
        Rung(
          [Xic('I:0/1'), Xic('I:0/2'), Ote('O:0/2')],
          title: 'FUNÇÕES LÓGICAS',
          comment: 'Contatos em série: função E.',
        ),
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
        'O:0/0': 'H1_NA',
        'O:0/1': 'H2_NF',
        'O:0/2': 'H3_E',
        'O:0/3': 'H4_OU',
      },
      descriptions: const {
        'I:0/0': 'Chave seletora\nS1',
        'I:0/1': 'Chave seletora\nS2',
        'I:0/2': 'Chave seletora\nS3',
      },
    ),
  ),
  LadderExample(
    name: 'Set/Reset (OTL/OTU)',
    momentaryInputs: const {0, 1},
    program: Program(
      [
        Rung(
          [Xic('I:0/0'), Otl('O:0/0')],
          title: 'SET / RESET',
          comment: 'OTL: B1 liga K1 e o bit fica travado.',
        ),
        Rung([Xic('I:0/1'), Otu('O:0/0')], comment: 'OTU: B0 destrava K1.'),
      ],
      symbols: const {'I:0/0': 'B1_LIGA', 'I:0/1': 'B0_DESLIGA', 'O:0/0': 'K1_MOTOR'},
      descriptions: const {
        'I:0/0': 'Botão liga\nmotor M1',
        'I:0/1': 'Botão desliga\nmotor M1',
        'O:0/0': 'Contator do\nmotor M1',
      },
    ),
  ),
  LadderExample(name: 'Novo programa', program: const Program([])),
];

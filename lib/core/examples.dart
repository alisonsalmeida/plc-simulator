import 'package:plc_core/plc_core.dart';

import '../models/ladder_example.model.dart';

/// Bundled examples for the first CLP II lessons (contacts, coils, timers and counters). UI text is pt-BR.
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
  LadderExample(
    name: 'Partida com retardo (TON)',
    momentaryInputs: const {0, 1},
    program: Program(
      [
        Rung(
          [
            Branch([
              [Xic('I:0/0')],
              [Xic('B3:0/0')],
            ]),
            Xio('I:0/1'),
            Ote('B3:0/0'),
          ],
          title: 'PARTIDA COM RETARDO',
          comment: 'B1 liga a sequência e B0 a desliga. O bit B3:0/0 faz o selo.',
        ),
        Rung(
          [Xic('B3:0/0'), Ton('T4:0', TimeBase.second, 5)],
          comment: 'Temporizador na energização: conta 5 s com a sequência ligada.',
        ),
        Rung(
          [Xic('T4:0/DN'), Ote('O:0/0')],
          comment: 'Passados os 5 s (DN), o contator K1 liga o motor M1.',
        ),
      ],
      symbols: const {
        'I:0/0': 'B1_LIGA',
        'I:0/1': 'B0_DESLIGA',
        'B3:0/0': 'SEQ_LIGADA',
        'T4:0': 'T_PARTIDA',
        'O:0/0': 'K1_MOTOR',
      },
      descriptions: const {
        'I:0/0': 'Botão liga\nmotor M1',
        'I:0/1': 'Botão desliga\nmotor M1 (NF)',
        'T4:0': 'Retardo de\n5 s na partida',
        'O:0/0': 'Contator do\nmotor M1',
      },
    ),
  ),
  LadderExample(
    name: 'Contador de peças (CTU)',
    momentaryInputs: const {2, 3},
    program: Program(
      [
        Rung(
          [Xic('I:0/2'), Ctu('C5:0', 10)],
          title: 'CONTADOR DE PEÇAS',
          comment: 'Cada pulso do sensor S3 conta uma peça.',
        ),
        Rung(
          [Xic('C5:0/DN'), Ote('O:0/1')],
          comment: 'Com 10 peças (DN) acende a lâmpada H1.',
        ),
        Rung(
          [
            Branch([
              [Xic('I:0/3')],
              [Xic('B3:0/0')],
            ]),
            Res('C5:0'),
          ],
          comment: 'O botão S4 (ou o bit B3:0/0) zera o contador.',
        ),
      ],
      symbols: const {
        'I:0/2': 'S3_PECA',
        'I:0/3': 'S4_ZERA',
        'C5:0': 'C_PECAS',
        'O:0/1': 'H1_LOTE',
      },
      descriptions: const {
        'I:0/2': 'Sensor de\npeças',
        'I:0/3': 'Botão zera\ncontador',
        'C5:0': 'Peças do lote',
        'O:0/1': 'Lâmpada\nlote completo',
      },
    ),
  ),
  LadderExample(
    name: 'Movimentação de dados (MOV/MVM/CLR)',
    momentaryInputs: const {0, 1, 2},
    program: Program(
      [
        Rung(
          [Xic('I:0/0'), Mov('100', 'N7:0')],
          title: 'MOVIMENTAÇÃO DE DADOS',
          comment: 'MOV: S1 grava o valor 100 na palavra N7:0.',
        ),
        Rung(
          [Xic('I:0/1'), Mvm('N7:0', '000Fh', 'O:0')],
          comment: 'MVM: S2 copia só os 4 bits baixos de N7:0 para as lâmpadas. '
              'O resultado fica retido em O:0 depois que S2 solta.',
        ),
        Rung(
          [Xic('I:0/2'), Clr('N7:0')],
          comment: 'CLR: S3 zera N7:0.',
        ),
      ],
      symbols: const {'I:0/0': 'S1_GRAVA', 'I:0/1': 'S2_COPIA', 'I:0/2': 'S3_ZERA'},
    ),
  ),
  LadderExample(
    name: 'Comparação de nível (GRT/LES/LIM)',
    program: Program(
      [
        Rung(
          [Grt('N7:0', '80'), Ote('O:0/0')],
          title: 'COMPARAÇÃO DE NÍVEL',
          comment: 'N7:0 é o nível do tanque (0 a 100). Altere-o na janela Data Files. '
              'GRT: nível acima de 80 liga o alarme de nível alto.',
        ),
        Rung(
          [Les('N7:0', '20'), Ote('O:0/1')],
          comment: 'LES: nível abaixo de 20 liga o alarme de nível baixo.',
        ),
        Rung(
          [Lim('20', 'N7:0', '80'), Ote('O:0/2')],
          comment: 'LIM: nível entre 20 e 80 (inclusive) liga a lâmpada de nível normal.',
        ),
      ],
      symbols: const {'N7:0': 'NIVEL_TANQUE', 'O:0/0': 'ALARME_ALTO', 'O:0/1': 'ALARME_BAIXO', 'O:0/2': 'NIVEL_NORMAL'},
    ),
  ),
  LadderExample(
    name: 'Escalonamento analógico (SCL/ADD/DIV)',
    program: Program(
      [
        Rung(
          [Xic('I:0/0'), Scl('N7:0', '610', '0', 'N7:1')],
          title: 'ESCALONAMENTO ANALÓGICO',
          comment: 'Ligue S1 e escreva em N7:0 o valor bruto do sensor (0 a 16383) na janela Data Files. '
              'SCL: N7:1 = N7:0 x 610 / 10000, ou seja, 0 a 1000 (aproximadamente).',
        ),
        Rung(
          [Xic('I:0/0'), Add('N7:1', '5', 'N7:2')],
          comment: 'ADD: soma a constante de calibração (5) ao valor escalonado.',
        ),
        Rung(
          [Xic('I:0/0'), Div('N7:2', '10', 'N7:3')],
          comment: 'DIV: divide por 10; o resultado é arredondado para o inteiro mais próximo.',
        ),
        Rung(
          [Grt('N7:3', '50'), Ote('O:0/0')],
          comment: 'GRT: com N7:3 acima de 50 a lâmpada de nível alto acende.',
        ),
      ],
      symbols: const {
        'I:0/0': 'S1_HABILITA',
        'N7:0': 'SENSOR_BRUTO',
        'N7:1': 'ESCALONADO',
        'N7:2': 'CALIBRADO',
        'N7:3': 'VALOR_FINAL',
        'O:0/0': 'NIVEL_ALTO',
      },
    ),
  ),
  LadderExample(
    name: 'Analógico: sensor 4–20 mA → saída 0–10 V',
    program: Program(
      [
        Rung(
          [Scl('I:1.0', '7630', '-2500', 'N7:0')],
          title: 'ENTRADA E SAÍDA ANALÓGICAS',
          comment: 'I:1.0 é um sensor de nível 4–20 mA (4 mA = 3277, 20 mA = 16384). '
              'SCL: N7:0 = I:1.0 x 7630 / 10000 - 2500, ou seja, 0 a 10000 (0,01 %).',
        ),
        Rung(
          [Div('N7:0', '100', 'N7:1')],
          comment: 'DIV: nível em porcentagem (0 a 100) em N7:1.',
        ),
        Rung([Grt('N7:1', '80'), Ote('O:0/0')], comment: 'Nível acima de 80 %: alarme de nível alto.'),
        Rung([Les('N7:1', '20'), Ote('O:0/1')], comment: 'Nível abaixo de 20 %: alarme de nível baixo.'),
        Rung(
          [Scl('N7:0', '32764', '0', 'O:2.0')],
          comment: 'SCL: O:2.0 = N7:0 x 32764 / 10000, ou seja, 0 a 32764 (0 a 10 V no módulo de saída).',
        ),
        Rung(
          [Les('N7:0', '0'), Mov('0', 'O:2.0')],
          comment: 'Sensor abaixo de 4 mA (fio rompido): mantém a saída analógica em 0 V.',
        ),
      ],
      symbols: const {
        'I:1.0': 'SENSOR_NIVEL',
        'N7:0': 'NIVEL_CENTI_PCT',
        'N7:1': 'NIVEL_PCT',
        'O:0/0': 'ALARME_ALTO',
        'O:0/1': 'ALARME_BAIXO',
        'O:2.0': 'VALVULA_PROP',
      },
    ),
  ),
  LadderExample(name: 'Novo programa', program: const Program([])),
];

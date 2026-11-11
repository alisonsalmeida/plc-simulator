import 'package:flutter/material.dart';
import 'package:plc_core/plc_core.dart';

import '../../../models/runtime_state.model.dart';
import '../../../theme/app_theme.dart';

/// Width of a timer/counter box with its output stubs.
const boxCellW = 160.0;

/// Distance from the top of the box to the rung wire (the middle of the title row).
const boxWireY = 22.5;

const _boxW = 124.0;
const _rowH = 15.0;
const _stubGap = 4.0;
const _stubLabelW = boxCellW - _boxW - 2 * _stubGap;

/// RSLogix style box of a timer or counter instruction: mnemonic and title, element data
/// rows, and the output stubs on the right. Bits and ACC come from the live data table when online.
class BoxCell extends StatelessWidget {
  const BoxCell({
    super.key,
    required this.instruction,
    required this.above,
    required this.symbol,
    required this.description,
    required this.runtime,
    required this.online,
    required this.powered,
    required this.onTap,
    this.lit = false,
  });

  final Instruction instruction;

  /// Height reserved above the box for the description and symbol bands.
  final double above;
  final String? symbol;
  final String? description;
  final RuntimeState runtime;
  final bool online;

  /// Whether power flows out of the instruction (word boxes are highlighted by it).
  final bool powered;

  /// Whether the whole rung is energized (the rung wire through the box is drawn green).
  final bool lit;
  final VoidCallback? onTap;

  ElementAddress get _element => (instruction as BoxInstruction).element;

  bool _bit(int bit) => online && runtime.bit(_element.bitAt(bit));

  /// Box is highlighted while the instruction is enabled: EN for timers, CU/CD for counters.
  bool get active => switch (instruction) {
        TimerInstruction() => _bit(TimerBit.en),
        Ctu() => _bit(CounterBit.cu),
        Ctd() => _bit(CounterBit.cd),
        WordInstruction() => online && powered,
        final CompareInstruction c => online && c.holds(_read),
        final Lim l => online && l.holds(_read),
        _ => false,
      };

  int _read(Operand o) => switch (o) {
        Constant(:final value) => value,
        FloatConstant(:final value) => value.round(),
        WordAddress(file: BitFile.float) => runtime.float(o).round(),
        WordAddress() => runtime.word(o),
      };

  static String titleOf(Instruction i) => switch (i) {
        Ton() => 'Timer On Delay',
        Tof() => 'Timer Off Delay',
        Rto() => 'Retentive Timer On',
        Ctu() => 'Count Up',
        Ctd() => 'Count Down',
        Mov() => 'Move',
        Mvm() => 'Masked Move',
        Clr() => 'Clear',
        Equ() => 'Equal',
        Neq() => 'Not Equal',
        Les() => 'Less Than',
        Leq() => 'Less Than or Eql',
        Grt() => 'Greater Than',
        Geq() => 'Grtr Than or Eql',
        Lim() => 'Limit Test',
        Add() => 'Add',
        Sub() => 'Subtract',
        Mul() => 'Multiply',
        Div() => 'Divide',
        Neg() => 'Negate',
        Sqr() => 'Square Root',
        Scl() => 'Scale',
        And() => 'Bitwise AND',
        Or() => 'Bitwise Inclusive OR',
        Xor() => 'Bitwise Exclusive OR',
        Not() => 'Logical NOT',
        Mod() => 'Modulo',
        Xpy() => 'Exponentiation',
        Swp() => 'Swap',
        Tod() => 'Convert to BCD',
        Frd() => 'Convert from BCD',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final ins = instruction;
    final singleWire = ins is! BoxInstruction;
    final isTimer = ins is TimerInstruction;
    final rows = <(String, String)>[
      if (ins is WordInstruction) ..._wordRows(ins) else if (ins is CompareInstruction) ...[
        ..._operandRows('Source A', ins.sourceA),
        ..._operandRows('Source B', ins.sourceB),
      ] else if (ins is Lim) ...[
        ..._operandRows('Low Lim', ins.low),
        ..._operandRows('Test', ins.test),
        ..._operandRows('High Lim', ins.high),
      ] else ...[
        (isTimer ? 'Timer' : 'Counter', _element.toString()),
        if (ins is TimerInstruction) ('Time Base', ins.timeBase.label),
        ('Preset', '${switch (ins) {
          TimerInstruction(:final preset) || CounterInstruction(:final preset) => preset,
          _ => 0,
        }}<'),
        ('Accum', '${online ? runtime.acc(_element) : 0}<'),
      ],
    ];
    final height = (2 + rows.length) * _rowH;
    final (firstStub, secondStub) = isTimer ? ('EN', 'DN') : (ins is Ctd ? 'CD' : 'CU', 'DN');
    final firstBit = isTimer ? TimerBit.en : (ins is Ctd ? CounterBit.cd : CounterBit.cu);
    final secondBit = isTimer ? TimerBit.dn : CounterBit.dn;
    Widget band(String text, Color color) => Container(
          width: 100,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(text, textScaler: TextScaler.noScaling, style: LadderStyle.text),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: SizedBox(
          width: boxCellW,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: above,
              width: boxCellW,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (description != null) band(description!, LadderStyle.commentBand),
                  if (symbol != null) band(symbol!, LadderStyle.titleBand),
                ],
              ),
            ),
            SizedBox(
              height: height,
              child: Stack(children: [
                Positioned(
                  left: 0,
                  top: 0,
                  width: _boxW,
                  height: height,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: active ? LadderStyle.energized : LadderStyle.wire,
                        width: active ? 2 : 1,
                      ),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _row(ins.mnemonic, bold: true),
                      _row(titleOf(ins)),
                      for (final (label, value) in rows) _row(label, value: value),
                    ]),
                  ),
                ),
                if (singleWire)
                  Positioned(
                    left: _boxW,
                    width: boxCellW - _boxW,
                    top: lit ? boxWireY - 0.5 : boxWireY,
                    height: lit ? 2 : 1,
                    child: ColoredBox(color: lit ? LadderStyle.energized : LadderStyle.wire),
                  )
                else ...[
                  _stub(firstStub, boxWireY, _bit(firstBit), continues: true, lit: lit),
                  _stub(secondStub, boxWireY + 2 * _rowH, _bit(secondBit), continues: false),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  /// Operand rows of a word instruction: an address is followed by its live value
  /// (`100<`), a constant shows only the number.
  List<(String, String)> _wordRows(WordInstruction ins) => switch (ins) {
        Mov() => [..._operandRows('Source', ins.source), ..._operandRows('Dest', ins.dest)],
        Mvm() => [
            ..._operandRows('Source', ins.source),
            ..._operandRows('Mask', ins.mask, hex: true),
            ..._operandRows('Dest', ins.dest),
          ],
        Clr() => _operandRows('Dest', ins.dest),
        BinaryMathInstruction() => [
            ..._operandRows('Source A', ins.sourceA),
            ..._operandRows('Source B', ins.sourceB),
            ..._operandRows('Dest', ins.dest),
          ],
        BinaryLogicInstruction() => [
            ..._operandRows('Source A', ins.sourceA),
            ..._operandRows('Source B', ins.sourceB),
            ..._operandRows('Dest', ins.dest),
          ],
        Swp() => [
            ..._operandRows('Source', ins.source),
            ..._operandRows('Dest', ins.dest),
          ],
        Tod(:final source, :final dest) || Frd(:final source, :final dest) => [
            ..._operandRows('Source', source),
            ..._operandRows('Dest', dest),
          ],
        Not() => [
            ..._operandRows('Source', ins.source),
            ..._operandRows('Dest', ins.dest),
          ],
        UnaryMathInstruction() => [
            ..._operandRows('Source', ins.source),
            ..._operandRows('Dest', ins.dest),
          ],
        Scl() => [
            ..._operandRows('Source', ins.source),
            ..._operandRows('Rate [/10000]', ins.rate),
            ..._operandRows('Offset', ins.offset),
            ..._operandRows('Dest', ins.dest),
          ],
      };

  List<(String, String)> _operandRows(String label, Operand o, {bool hex = false}) => switch (o) {
        Constant() || FloatConstant() => [(label, o.format(hex: hex))],
        WordAddress(file: BitFile.float) => [(label, o.toString()), ('', '${online ? formatFloat(runtime.float(o)) : 0.0}<')],
        WordAddress() => [(label, o.toString()), ('', '${online ? runtime.word(o) : 0}<')],
      };

  Widget _row(String label, {String? value, bool bold = false}) => SizedBox(
        height: _rowH,
        child: Padding(
          padding: const EdgeInsets.only(left: 4, right: 2),
          child: Row(children: [
            Flexible(
              fit: value == null ? FlexFit.loose : FlexFit.tight,
              flex: value == null ? 1 : 0,
              child: SizedBox(
                width: value == null ? null : 58,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textScaler: TextScaler.noScaling,
                  style: LadderStyle.text.copyWith(fontWeight: bold ? FontWeight.bold : null),
                ),
              ),
            ),
            if (value != null)
              Text(value, textScaler: TextScaler.noScaling, style: LadderStyle.text),
          ]),
        ),
      );

  /// Output stub at [y]: a short wire and the `(XX)` label, green when its bit is 1. The
  /// stub of the rung wire ([continues]) runs on to the cell edge.
  Widget _stub(String label, double y, bool on, {required bool continues, bool lit = false}) => Positioned(
        left: _boxW,
        top: y - _rowH / 2,
        width: boxCellW - _boxW,
        height: _rowH,
        child: Stack(alignment: Alignment.center, children: [
          Positioned(
            left: 0,
            width: continues ? boxCellW - _boxW : _stubGap + 2,
            top: lit ? _rowH / 2 - 0.5 : _rowH / 2,
            height: lit ? 2 : 1,
            child: ColoredBox(color: lit ? LadderStyle.energized : LadderStyle.wire),
          ),
          Positioned(
            left: _stubGap,
            width: _stubLabelW,
            top: 0,
            height: _rowH,
            child: ColoredBox(
              color: Colors.white,
              child: Center(
                child: Text(
                  '($label)',
                  textScaler: TextScaler.noScaling,
                  style: LadderStyle.text.copyWith(
                    color: on ? LadderStyle.energized : Colors.black,
                    fontWeight: on ? FontWeight.bold : null,
                  ),
                ),
              ),
            ),
          ),
        ]),
      );
}

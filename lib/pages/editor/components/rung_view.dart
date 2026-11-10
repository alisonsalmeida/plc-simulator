import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/program.controller.dart';
import '../../../models/runtime_state.model.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/ladder_assets.dart';
import 'box_cell.dart';
import 'rung_actions.dart';

/// Width of the gutter left of the left power rail (holds the rung number).
const rungGutterW = 52.0;
const _railW = 1.0;
const _cellW = 100.0;
const _slotW = 20.0;
const _joinW = 5.0;
const _glyphW = 28.0;
const _resGlyphW = 44.0; // the "(RES)" coil
const _glyphH = 24.0;
const _lineH = 14.0; // address line above the symbol and bit line below it
const _fillMinW = 40.0; // minimum length of the stretchy wire in front of the outputs
const _bottomPad = 10.0;

/// Smallest width a rung needs: gutter, rails, its elements and some wire.
double rungMinWidth(Rung rung) =>
    rungGutterW + 2 * _railW + _seriesWidth(rung.elements) + _fillMinW;

/// Smallest width of the END rung.
const endRungMinWidth = rungGutterW + 2 * _railW + 120;

String _fourDigits(int n) => n.toString().padLeft(4, '0');

double _seriesWidth(List<RungElement> elements) =>
    (elements.length + 1) * _slotW + elements.fold(0.0, (w, e) => w + _elementWidth(e));

double _elementWidth(RungElement e) => switch (e) {
      Ton() || Tof() || Rto() || Ctu() || Ctd() => boxCellW,
      Instruction() => _cellW,
      Branch(:final paths) =>
        2 * _joinW + paths.fold(0.0, (w, p) => w > _seriesWidth(p) ? w : _seriesWidth(p)),
    };

double _textHeight(String text, double width) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: LadderStyle.text),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout(maxWidth: width);
  final h = painter.height;
  painter.dispose();
  return h;
}

double _boxHeight(String text) => _textHeight(text, _cellW - 6) + 4;

/// Height above the wire of an instruction cell: description box, symbol box and, for a
/// glyph, the address line. A box instruction reaches [boxWireY] down from its top edge, so
/// the bands sit above that and the wire is half a glyph below the same point.
double _cellTop(Instruction ins, Program program) {
  final description = program.descriptionOf(ins);
  final symbol = program.symbolOf(ins);
  return (description == null ? 0 : _boxHeight(description)) +
      (symbol == null ? 0 : _boxHeight(symbol)) +
      (_isBox(ins) ? boxWireY - _glyphH / 2 : _lineH);
}

bool _isBox(RungElement e) => e is BoxInstruction && e is! Res;

/// Height of a series above its wire: the tallest cell (a branch counts as its first path).
double _seriesTop(List<RungElement> elements, Program program) {
  var top = _lineH;
  for (final e in elements) {
    final t = switch (e) {
      Instruction() => _cellTop(e, program),
      Branch(:final paths) => _seriesTop(paths.first, program),
    };
    if (t > top) top = t;
  }
  return top;
}

Widget _rail() => const SizedBox(
      width: _railW,
      child: ColoredBox(color: LadderStyle.wire),
    );

/// Both power rails over the full height of the enclosing [Stack].
List<Widget> _rails() => [
      Positioned(left: rungGutterW, top: 0, bottom: 0, width: _railW, child: _rail()),
      Positioned(right: 0, top: 0, bottom: 0, width: _railW, child: _rail()),
    ];

/// One rung: optional title and comment bands, then the ladder between the two power rails.
/// The rung number sits in the gutter on the wire; tapping it selects the rung.
class RungView extends ConsumerWidget {
  const RungView({
    super.key,
    required this.index,
    required this.rung,
    required this.program,
    required this.runtime,
    required this.selected,
  });

  final int index;
  final Rung rung;
  final Program program;
  final RuntimeState runtime;
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = runtime.mode != RuntimeMode.stop;
    final editable = !online;
    final actions = RungActions(context, ref, index, program);
    final trace = index < runtime.powerFlow.length ? runtime.powerFlow[index] : const <bool>[];
    final ladder = _Ladder(
      actions: actions,
      program: program,
      runtime: runtime,
      trace: trace,
      editable: editable,
    );
    final top = _seriesTop(rung.elements, program);
    final wireY = top + _glyphH / 2;
    final hasText = rung.title.isNotEmpty || rung.comment.isNotEmpty;
    final edit = editable ? actions.editTitleAndComment : null;
    final bandInset = const EdgeInsets.only(left: rungGutterW + _railW, right: _railW);
    return Stack(children: [
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: rungGutterW + _railW,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: selected ? Border.all(color: LadderStyle.selection, width: 2.5) : null,
          ),
        ),
      ),
      ..._rails(),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (rung.title.isNotEmpty)
          Padding(
            padding: bandInset,
            child: _Band(
              text: rung.title,
              color: LadderStyle.titleBand,
              align: TextAlign.center,
              onTap: edit,
            ),
          ),
        if (rung.comment.isNotEmpty)
          Padding(
            padding: bandInset,
            child: _Band(
              text: rung.comment,
              color: LadderStyle.commentBand,
              align: TextAlign.left,
              onTap: edit,
            ),
          ),
        if (!hasText && selected && editable)
          Padding(
            padding: bandInset,
            child: _Band(
              text: 'Toque para adicionar título e comentário',
              color: const Color(0xFFEEEEEE),
              align: TextAlign.left,
              italic: true,
              onTap: edit,
            ),
          ),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: rungGutterW + _railW,
            child: Padding(
              padding: EdgeInsets.only(top: wireY - 7, right: _railW),
              child: _RungNumber(index),
            ),
          ),
          Expanded(child: ladder.rung(rung)),
          const SizedBox(width: _railW),
        ]),
        const SizedBox(height: _bottomPad),
      ]),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: rungGutterW,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Focus.maybeOf(context)?.requestFocus();
            ref.read(programProvider.notifier).selectRung(index);
          },
        ),
      ),
    ]);
  }
}

class _RungNumber extends StatelessWidget {
  const _RungNumber(this.number);

  final int number;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 14,
        child: Center(
          child: Text(
            _fourDigits(number),
            textScaler: TextScaler.noScaling,
            style: LadderStyle.text.copyWith(fontSize: 12, color: LadderStyle.rungNumber),
          ),
        ),
      );
}

class _Band extends StatelessWidget {
  const _Band({
    required this.text,
    required this.color,
    required this.align,
    required this.onTap,
    this.italic = false,
  });

  final String text;
  final Color color;
  final TextAlign align;
  final bool italic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Text(
            text,
            textAlign: align,
            textScaler: TextScaler.noScaling,
            style: LadderStyle.text.copyWith(
              fontSize: 12,
              fontStyle: italic ? FontStyle.italic : null,
              color: italic ? Colors.black45 : null,
            ),
          ),
        ),
      );
}

/// The always-present last rung: rung number, wire and the `<END>` marker at the right rail.
/// It is not a program element and cannot be edited.
class EndRungView extends StatelessWidget {
  const EndRungView({super.key, required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    const wireY = _lineH + _glyphH / 2;
    return Stack(children: [
      ..._rails(),
      Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: rungGutterW + _railW,
            child: Padding(
              padding: const EdgeInsets.only(top: wireY - 7, right: _railW),
              child: _RungNumber(number),
            ),
          ),
          const Expanded(child: _Wire(wireY: wireY)),
          const Padding(
            padding: EdgeInsets.only(top: wireY - 8),
            child: _EndSymbol(),
          ),
          const SizedBox(width: _railW + 2),
        ]),
        const SizedBox(height: _lineH + _bottomPad),
      ]),
    ]);
  }
}

/// `<END>`: the word between two angle brackets, in wire blue.
class _EndSymbol extends StatelessWidget {
  const _EndSymbol();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BracketsPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text(
            'END',
            textScaler: TextScaler.noScaling,
            style: LadderStyle.text.copyWith(fontSize: 12, color: LadderStyle.wire, height: 1.3),
          ),
        ),
      );
}

class _BracketsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LadderStyle.wire
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final mid = size.height / 2;
    canvas.drawPath(
      Path()
        ..moveTo(7, 0)
        ..lineTo(0, mid)
        ..lineTo(7, size.height),
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - 7, 0)
        ..lineTo(size.width, mid)
        ..lineTo(size.width - 7, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_BracketsPainter oldDelegate) => false;
}

/// Builds the widget tree of a rung, walking elements in the engine's traversal order so the
/// scan trace can be consumed one instruction at a time.
class _Ladder {
  _Ladder({
    required this.actions,
    required this.program,
    required this.runtime,
    required this.trace,
    required this.editable,
  });

  final RungActions actions;
  final Program program;
  final RuntimeState runtime;
  final List<bool> trace;
  final bool editable;

  int _next = 0;

  /// Power out of the next instruction in traversal order.
  bool _consume() {
    final v = _next < trace.length && trace[_next];
    _next++;
    return v;
  }

  /// Whether the instruction is logically true (drawn highlighted when online): contacts
  /// by their examined bit, coils by the output bit, OTU by the rung power.
  bool _isTrue(Instruction ins, bool powerOut) {
    if (editable || runtime.data.isEmpty) return false;
    return switch (ins) {
      Xic(:final address) => runtime.bit(address),
      Xio(:final address) => !runtime.bit(address),
      Ote(:final address) || Otl(:final address) => runtime.bit(address),
      Otu() || Res() => powerOut,
      // Boxes are highlighted by BoxCell from their own status bits.
      TimerInstruction() || CounterInstruction() => false,
    };
  }

  Widget rung(Rung rung) {
    var tail = rung.elements.length;
    while (tail > 0 && _isOutput(rung.elements[tail - 1])) {
      tail--;
    }
    final top = _seriesTop(rung.elements, program);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _series(rung.elements, const [], tail, top),
    );
  }

  bool _isOutput(RungElement e) => e is Instruction && e.isOutput;

  /// Slots and elements of one series, [top] above the wire; the stretchy wire goes before
  /// slot [fillAt] (trailing outputs stay right-aligned).
  List<Widget> _series(List<RungElement> elements, List<int> prefix, int fillAt, double top) {
    final children = <Widget>[];
    for (var i = 0; i <= elements.length; i++) {
      if (i == fillAt) children.add(Expanded(child: _Wire(wireY: top + _glyphH / 2)));
      final path = [...prefix, i];
      children.add(_Slot(
        wireY: top + _glyphH / 2,
        height: top + _glyphH + _lineH,
        enabled: editable,
        onDrop: (tool) => actions.dropOnSlot(path, tool),
      ));
      if (i == elements.length) break;
      switch (elements[i]) {
        case final Instruction ins:
          final out = _consume();
          final onTap = editable ? () => actions.editInstruction(path, ins) : null;
          children.add(switch (ins) {
            final BoxInstruction box when _isBox(box) => BoxCell(
                instruction: box,
                above: top - (boxWireY - _glyphH / 2),
                symbol: program.symbolOf(ins),
                description: program.descriptionOf(ins),
                runtime: runtime,
                online: !editable && runtime.data.isNotEmpty,
                onTap: onTap,
              ),
            _ => _Cell(
                instruction: ins,
                symbol: program.symbolOf(ins),
                description: program.descriptionOf(ins),
                top: top,
                energized: _isTrue(ins, out),
                onTap: onTap,
              ),
          });
        case final Branch branch:
          children.add(_branch(branch, path, top));
      }
    }
    return children;
  }

  Widget _branch(Branch branch, List<int> path, double top) {
    final width = _elementWidth(branch);
    final last = branch.paths.length - 1;
    return SizedBox(
      width: width,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var k = 0; k <= last; k++)
          _branchRow(
            // The first path shares the wire of the series it sits in.
            top: k == 0 ? top : _seriesTop(branch.paths[k], program),
            up: k > 0,
            down: k < last,
            series: branch.paths[k],
            path: [...path, k],
          ),
        if (editable) _AddPath(onDrop: (tool) => actions.dropOnNewPath(path, tool)),
      ]),
    );
  }

  Widget _branchRow({
    required double top,
    required bool up,
    required bool down,
    required List<RungElement> series,
    required List<int> path,
  }) {
    final wireY = top + _glyphH / 2;
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Join(wireY: wireY, up: up, down: down),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _series(series, path, series.length, top),
          ),
        ),
        _Join(wireY: wireY, up: up, down: down),
      ]),
    );
  }
}

/// Horizontal wire at [wireY]; give it a bounded width (Expanded/SizedBox).
class _Wire extends StatelessWidget {
  const _Wire({required this.wireY});

  final double wireY;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: wireY),
          child: Container(height: 1, color: LadderStyle.wire),
        ),
      );
}

/// Vertical connector at the side of a branch path: [up] from the row top to the wire,
/// [down] from the wire to the row bottom; the wire itself crosses it.
class _Join extends StatelessWidget {
  const _Join({required this.wireY, required this.up, required this.down});

  final double wireY;
  final bool up;
  final bool down;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _joinW,
        child: Stack(children: [
          Positioned(left: 0, right: 0, top: wireY, height: 1, child: _rail()),
          Positioned(
            left: _joinW / 2 - 0.5,
            width: 1,
            top: up ? 0 : wireY,
            bottom: down ? 0 : null,
            height: down ? null : (up ? wireY + 1 : 0),
            child: _rail(),
          ),
        ]),
      );
}

/// Narrow drop target between elements of a series. Accepts instruction and branch tools.
class _Slot extends StatelessWidget {
  const _Slot({
    required this.wireY,
    required this.height,
    required this.enabled,
    required this.onDrop,
  });

  final double wireY;
  final double height;
  final bool enabled;
  final void Function(String tool) onDrop;

  @override
  Widget build(BuildContext context) {
    final wire = Positioned(left: 0, right: 0, top: wireY, height: 1, child: _rail());
    if (!enabled) return SizedBox(width: _slotW, height: height, child: Stack(children: [wire]));
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != LadderAssets.rung,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, hovering, _) => SizedBox(
        width: _slotW,
        height: height,
        child: Stack(children: [
          wire,
          if (hovering.isNotEmpty)
            Positioned(
              left: 1,
              right: 1,
              top: wireY - 14,
              height: 28,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.35),
                  border: Border.all(color: primary),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Drop target between rungs that accepts the New Rung tool.
class RungGap extends StatelessWidget {
  const RungGap({super.key, required this.enabled, required this.onDrop});

  final bool enabled;
  final VoidCallback onDrop;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final content = Stack(children: [
      ..._rails(),
    ]);
    if (!enabled) return SizedBox(height: 8, child: content);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data == LadderAssets.rung,
      onAcceptWithDetails: (_) => onDrop(),
      builder: (_, hovering, _) => SizedBox(
        height: 8,
        child: Stack(children: [
          if (hovering.isNotEmpty)
            Positioned.fill(child: ColoredBox(color: primary.withValues(alpha: 0.4))),
          ..._rails(),
        ]),
      ),
    );
  }
}

/// "+ caminho" target under a branch: dropping adds a new parallel path.
class _AddPath extends StatelessWidget {
  const _AddPath({required this.onDrop});

  final void Function(String tool) onDrop;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => d.data != LadderAssets.rung,
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (_, hovering, _) => Container(
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovering.isEmpty ? null : primary.withValues(alpha: 0.35),
          border: Border.all(color: hovering.isEmpty ? Colors.black26 : primary),
        ),
        child: Text(
          '+ caminho',
          textScaler: TextScaler.noScaling,
          style: LadderStyle.text.copyWith(fontSize: 10, color: Colors.black54),
        ),
      ),
    );
  }
}

/// One instruction: description and symbol boxes, word address above the symbol on the
/// wire, bit number below.
class _Cell extends StatelessWidget {
  const _Cell({
    required this.instruction,
    required this.symbol,
    required this.description,
    required this.top,
    required this.energized,
    required this.onTap,
  });

  final Instruction instruction;
  final String? symbol;
  final String? description;
  final double top;
  final bool energized;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ins = instruction;
    final isRes = ins is Res;
    final glyphW = isRes ? _resGlyphW : _glyphW;
    final (topText, bottomText) = switch (ins) {
      BitInstruction(:final address) => ('${address.file.prefix}:${address.word}', address.bitLabel),
      BoxInstruction(:final element) => (element.toString(), ''),
    };
    final side = (_cellW - glyphW) / 2;
    final wireY = _glyphH / 2;
    Widget box(String text, Color color) => Container(
          width: _cellW,
          color: color,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          child: Text(text, textScaler: TextScaler.noScaling, style: LadderStyle.text),
        );
    Widget line(String text) => SizedBox(
          height: _lineH,
          child: Center(
            child: Text(text, textScaler: TextScaler.noScaling, style: LadderStyle.text),
          ),
        );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: MouseRegion(
        cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
        child: SizedBox(
          width: _cellW,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: top,
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (description != null) box(description!, LadderStyle.commentBand),
                if (symbol != null) box(symbol!, LadderStyle.titleBand),
                line(topText),
              ]),
            ),
            SizedBox(
              height: _glyphH,
              child: Stack(children: [
                Positioned(left: 0, width: side, top: wireY, height: 1, child: _rail()),
                Positioned(right: 0, width: side, top: wireY, height: 1, child: _rail()),
                if (isRes)
                  Positioned(
                    left: side,
                    top: 0,
                    width: glyphW,
                    height: _glyphH,
                    child: Center(
                      child: Text(
                        '(RES)',
                        textScaler: TextScaler.noScaling,
                        style: LadderStyle.text.copyWith(
                          fontWeight: FontWeight.bold,
                          color: energized ? LadderStyle.energized : LadderStyle.wire,
                        ),
                      ),
                    ),
                  )
                else ...[
                  if (energized) Positioned(left: side, top: 0, child: _Highlight(ins.isOutput)),
                  Positioned(
                    left: side,
                    top: 0,
                    child: ladderSymbol(
                      ins.mnemonic,
                      color: LadderStyle.wire,
                      width: _glyphW,
                      height: _glyphH,
                    ),
                  ),
                ],
              ]),
            ),
            line(bottomText),
          ]),
        ),
      ),
    );
  }
}

/// Green marker behind a true instruction: bars at the contact sides, a ring around a coil.
class _Highlight extends StatelessWidget {
  const _Highlight(this.coil);

  final bool coil;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _glyphW,
        height: _glyphH,
        child: coil
            ? Align(
                child: Container(
                  width: 18,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: LadderStyle.energized, width: 3),
                  ),
                ),
              )
            : Stack(children: [
                for (final x in const [8.5, 16.5])
                  Positioned(
                    left: x,
                    top: 2,
                    width: 3,
                    height: _glyphH - 4,
                    child: const ColoredBox(color: LadderStyle.energized),
                  ),
              ]),
      );
}

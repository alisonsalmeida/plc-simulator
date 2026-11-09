import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:plc_core/plc_core.dart';

import '../../../theme/app_theme.dart';

const _cellW = 104.0;
const _rowH = 76.0;
const _wireY = 50.0; // wire height inside a row
const _rail = 24.0; // space for the rung number left of the left rail

/// One rung: comment above, ladder drawing with power flow below.
class RungView extends StatelessWidget {
  const RungView({
    super.key,
    required this.index,
    required this.rung,
    required this.program,
    required this.trace,
    required this.online,
  });

  final int index;
  final Rung rung;
  final Program program;
  final List<bool> trace;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final tailStart = _tailStart(rung.elements);
    final contentW = _seriesWidth(rung.elements) * _cellW + 2 * _rail + _cellW / 2;
    final height = _seriesHeight(rung.elements) * _rowH;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (rung.comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: _rail),
            child: Text(rung.comment, style: Theme.of(context).textTheme.bodySmall),
          ),
        LayoutBuilder(builder: (_, c) {
          final width = math.max(c.maxWidth, contentW);
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: CustomPaint(
              size: Size(width, height),
              painter: _RungPainter(
                index: index,
                rung: rung,
                tailStart: tailStart,
                program: program,
                trace: trace,
                online: online,
                textColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          );
        }),
      ]),
    );
  }
}

/// Index of the first of the trailing output instructions (drawn right-aligned).
int _tailStart(List<RungElement> elements) {
  var i = elements.length;
  while (i > 0 && elements[i - 1] is Instruction && (elements[i - 1] as Instruction).isOutput) {
    i--;
  }
  return i;
}

int _width(RungElement e) => switch (e) {
      Instruction() => 1,
      Branch(:final paths) => paths.map(_seriesWidth).fold(1, math.max),
    };

int _seriesWidth(List<RungElement> s) => s.fold(0, (w, e) => w + _width(e));

int _height(RungElement e) => switch (e) {
      Instruction() => 1,
      Branch(:final paths) => paths.fold(0, (h, p) => h + _seriesHeight(p)),
    };

int _seriesHeight(List<RungElement> s) => s.map(_height).fold(1, math.max);

class _RungPainter extends CustomPainter {
  _RungPainter({
    required this.index,
    required this.rung,
    required this.tailStart,
    required this.program,
    required this.trace,
    required this.online,
    required this.textColor,
  });

  final int index;
  final Rung rung;
  final int tailStart;
  final Program program;
  final List<bool> trace;
  final bool online;
  final Color textColor;

  late Canvas _canvas;
  int _next = 0; // next trace entry, consumed in the engine's traversal order

  @override
  void paint(Canvas canvas, Size size) {
    _canvas = canvas;
    _next = 0;
    final left = _rail;
    final right = size.width - _rail;
    _line(Offset(left, 0), Offset(left, size.height), online);
    _line(Offset(right, 0), Offset(right, size.height), false);
    _text('${index + 1}', Offset(0, _wireY - 8), 20);

    final body = rung.elements.sublist(0, tailStart);
    final tail = rung.elements.sublist(tailStart);
    var (power, x) = _series(body, left, 0, online);
    final tailX = right - _seriesWidth(tail) * _cellW;
    _line(Offset(x, _wireY), Offset(tailX, _wireY), power);
    (power, x) = _series(tail, tailX, 0, power);
    _line(Offset(x, _wireY), Offset(right, _wireY), power);
  }

  /// Draws a series of elements from (x, y); returns the power and x at its right end.
  (bool, double) _series(List<RungElement> elements, double x, double y, bool power) {
    for (final e in elements) {
      switch (e) {
        case Instruction():
          final out = _next < trace.length && trace[_next];
          _next++;
          _instruction(e, x, y, power, out);
          power = out;
          x += _cellW;
        case Branch(:final paths):
          final endX = x + _width(e) * _cellW;
          var pathY = y;
          var out = false;
          for (final path in paths) {
            final (p, px) = _series(path, x, pathY, power);
            _line(Offset(px, pathY + _wireY), Offset(endX, pathY + _wireY), p);
            if (pathY > y) {
              _line(Offset(x, pathY - _rowH + _wireY), Offset(x, pathY + _wireY), power);
              _line(Offset(endX, pathY - _rowH + _wireY), Offset(endX, pathY + _wireY), p || out);
            }
            out = out || p;
            pathY += _seriesHeight(path) * _rowH;
          }
          power = out;
          x = endX;
      }
    }
    return (power, x);
  }

  void _instruction(Instruction ins, double x, double y, bool powerIn, bool powerOut) {
    final cx = x + _cellW / 2;
    final wy = y + _wireY;
    const half = 12.0;
    _line(Offset(x, wy), Offset(cx - half, wy), powerIn);
    _line(Offset(cx + half, wy), Offset(x + _cellW, wy), powerOut);
    final p = _paint(powerOut);
    switch (ins) {
      case Xic() || Xio():
        _canvas
          ..drawLine(Offset(cx - half, wy - 14), Offset(cx - half, wy + 14), p)
          ..drawLine(Offset(cx + half, wy - 14), Offset(cx + half, wy + 14), p);
        if (ins is Xio) _canvas.drawLine(Offset(cx - half - 4, wy + 14), Offset(cx + half + 4, wy - 14), p);
      case Ote() || Otl() || Otu():
        final r = Rect.fromCircle(center: Offset(cx, wy), radius: half + 2);
        _canvas
          ..drawArc(r, math.pi * 0.7, math.pi * 0.6, false, p)
          ..drawArc(r, -math.pi * 0.3, math.pi * 0.6, false, p);
        if (ins is Otl) _text('L', Offset(cx - 5, wy - 9), 10);
        if (ins is Otu) _text('U', Offset(cx - 5, wy - 9), 10);
    }
    _text(program.symbolFor(ins.address) ?? '', Offset(x + 4, y + 4), _cellW - 8, bold: true);
    _text(ins.address.toString(), Offset(x + 4, y + 18), _cellW - 8);
  }

  Paint _paint(bool energized) => Paint()
    ..color = energized ? AppColors.energized : AppColors.wire
    ..strokeWidth = energized ? 3.5 : 2
    ..style = PaintingStyle.stroke;

  void _line(Offset a, Offset b, bool energized) => _canvas.drawLine(a, b, _paint(energized));

  void _text(String s, Offset at, double maxWidth, {bool bold = false}) {
    if (s.isEmpty) return;
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(color: textColor, fontSize: 12, fontWeight: bold ? FontWeight.w600 : null),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(_canvas, at);
  }

  @override
  bool shouldRepaint(_RungPainter old) =>
      old.trace != trace || old.online != online || old.rung != rung || old.textColor != textColor;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:plc_core/plc_core.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';

enum SevenSegmentMode { bcd, direct }

/// Segments a..g lit for each decimal digit 0..9.
const _digitSegments = <List<bool>>[
  [true, true, true, true, true, true, false],
  [false, true, true, false, false, false, false],
  [true, true, false, true, true, false, true],
  [true, true, true, true, false, false, true],
  [false, true, true, false, false, true, true],
  [true, false, true, true, false, true, true],
  [true, false, true, true, true, true, true],
  [true, true, true, false, false, false, false],
  [true, true, true, true, true, true, true],
  [true, true, true, true, false, true, true],
];

/// Segments a..g for the given output word [outputs] in [mode]. In BCD mode a nibble above 9
/// leaves the display blank.
List<bool> sevenSegmentsFor(int outputs, SevenSegmentMode mode) {
  if (mode == SevenSegmentMode.direct) {
    return [for (var i = 0; i < 7; i++) (outputs >> i) & 1 == 1];
  }
  final digit = outputs & 0xF;
  return digit <= 9 ? _digitSegments[digit] : List.filled(7, false);
}

/// Glowing 7-segment LED display of 1..4 digits on the chassis slot `s` it is connected to. BCD
/// mode: digit `n` decodes `O:s/4n..4n+3`; direct mode: one digit with segments a..g on `O:s/0..6`.
class SevenSegmentTile extends ConsumerStatefulWidget {
  const SevenSegmentTile({super.key});

  @override
  ConsumerState<SevenSegmentTile> createState() => _SevenSegmentTileState();
}

class _SevenSegmentTileState extends ConsumerState<SevenSegmentTile> {
  SevenSegmentMode _mode = SevenSegmentMode.bcd;
  int _count = 4;

  @override
  Widget build(BuildContext context) {
    final program = ref.watch(programProvider.select((s) => s.program));
    final slot = program.ioMapping.sevenSegmentSlot;
    final slots = [
      for (var s = 0; s < program.chassis.slots.length; s++)
        if (program.chassis.moduleAt(s).hasDigitalOutputs) s,
    ];
    final isAssociated = slot != null && slots.contains(slot);
    final element = isAssociated ? ioElement(BitFile.output, slot, null) : null;
    final outputs = ref.watch(
      runtimeProvider.select(
        (s) => !isAssociated || element == null
            ? 0
            : s.data[BitFile.output]?[element] ??
                  (slot == program.ioMapping.digitalOutputSlot ? s.outputs : 0),
      ),
    );
    final small = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.white);
    final direct = _mode == SevenSegmentMode.direct;
    final digits = direct ? 1 : _count;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DropdownButton<int?>(
                key: const ValueKey('seven-segment-slot'),
                value: isAssociated ? slot : null,
                dropdownColor: const Color(0xFF222222),
                style: small,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('⊘ Não Associado'),
                  ),
                  for (final s in slots)
                    DropdownMenuItem<int?>(value: s, child: Text('Slot $s')),
                ],
                onChanged: (s) =>
                    ref.read(programProvider.notifier).setSevenSegmentSlot(s),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<SevenSegmentMode>(
                  key: const ValueKey('seven-segment-mode'),
                  isExpanded: true,
                  value: _mode,
                  dropdownColor: const Color(0xFF222222),
                  style: small,
                  items: const [
                    DropdownMenuItem(
                      value: SevenSegmentMode.bcd,
                      child: Text('Modo BCD'),
                    ),
                    DropdownMenuItem(
                      value: SevenSegmentMode.direct,
                      child: Text('Segmentos Diretos'),
                    ),
                  ],
                  onChanged: (m) => setState(() => _mode = m ?? _mode),
                ),
              ),
              if (!direct) ...[
                const SizedBox(width: 8),
                DropdownButton<int>(
                  key: const ValueKey('seven-segment-digits'),
                  value: _count,
                  dropdownColor: const Color(0xFF222222),
                  style: small,
                  items: [
                    for (var n = 1; n <= 4; n++)
                      DropdownMenuItem(
                        value: n,
                        child: Text('$n dígito${n > 1 ? 's' : ''}'),
                      ),
                  ],
                  onChanged: (n) => setState(() => _count = n ?? _count),
                ),
              ],
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = digits - 1; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        key: ValueKey('seven-segment-digit-$i'),
                        size: const Size(40, 70),
                        painter: SevenSegmentPainter(
                          isAssociated
                              ? sevenSegmentsFor(outputs >> (i * 4), _mode)
                              : List.filled(7, false),
                        ),
                      ),
                      Text(
                        isAssociated
                            ? (direct
                                  ? 'O:$slot/0..6'
                                  : 'O:$slot/${i * 4}..${i * 4 + 3}')
                            : '⊘',
                        style: small,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class SevenSegmentPainter extends CustomPainter {
  const SevenSegmentPainter(this.segments);

  /// Segments a..g.
  final List<bool> segments;

  static const on = Color(0xFFFF1744);
  static const off = Color(0xFF2B0000);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = w * 0.16; // segment thickness
    final m = t * 0.15; // gap
    // a, b, c, d, e, f, g as rectangles.
    final rects = <Rect>[
      Rect.fromLTRB(t + m, 0, w - t - m, t),
      Rect.fromLTRB(w - t, t + m, w, h / 2 - m),
      Rect.fromLTRB(w - t, h / 2 + m, w, h - t - m),
      Rect.fromLTRB(t + m, h - t, w - t - m, h),
      Rect.fromLTRB(0, h / 2 + m, t, h - t - m),
      Rect.fromLTRB(0, t + m, t, h / 2 - m),
      Rect.fromLTRB(t + m, h / 2 - t / 2, w - t - m, h / 2 + t / 2),
    ];
    for (var i = 0; i < 7; i++) {
      final lit = segments[i];
      final rrect = RRect.fromRectAndRadius(rects[i], Radius.circular(t / 2));
      if (lit) {
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = on.withValues(alpha: 0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      canvas.drawRRect(rrect, Paint()..color = lit ? on : off);
    }
  }

  @override
  bool shouldRepaint(SevenSegmentPainter old) =>
      old.segments.toString() != segments.toString();
}

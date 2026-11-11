import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

const gridCellH = 20.0;
const gridLabelW = 52.0;
/// Amber of the force indicators (grid cells, I/O panel badge).
const forceAmber = Color(0xFFFFC000);
const _gridLine = Color(0xFFB0B0B0);

TextStyle get gridText => LadderStyle.text.copyWith(fontSize: 12);

/// One white cell of a data table grid with a thin grey border; header cells are grey.
class GridCell extends StatelessWidget {
  const GridCell(
    this.text, {
    super.key,
    required this.width,
    this.selected = false,
    this.header = false,
    this.forced = false,
    this.onTap,
  });

  final String text;
  final double width;
  final bool selected;
  final bool header;

  /// The bit is forced (I/O forcing): amber background.
  final bool forced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: width,
          height: gridCellH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF000080)
                : (forced ? forceAmber : (header ? const Color(0xFFE8E6E0) : Colors.white)),
            border: Border.all(color: _gridLine, width: 0.5),
          ),
          child: Text(
            text,
            maxLines: 1,
            textScaler: TextScaler.noScaling,
            style: gridText.copyWith(
              color: selected ? Colors.white : Colors.black,
              fontWeight: header ? FontWeight.bold : null,
            ),
          ),
        ),
      );
}

/// A grid row: the row label cell followed by [cells].
class GridRow extends StatelessWidget {
  const GridRow({super.key, required this.label, required this.cells});

  final String label;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        GridCell(label, width: gridLabelW, header: true),
        ...cells,
      ]);
}

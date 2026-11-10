import 'package:flutter/material.dart';

/// Horizontal drag handle between the ladder and the Data Files pane.
/// [onDrag] receives the vertical delta in pixels (negative when dragged up).
class PaneSplitter extends StatelessWidget {
  const PaneSplitter({super.key, required this.onDrag});

  static const double thickness = 6;

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeRow,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
        child: SizedBox(
          height: thickness,
          child: Center(child: Divider(height: 1, color: Theme.of(context).dividerColor)),
        ),
      ),
    );
  }
}

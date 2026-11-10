import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';

/// Read-only vertical level bar (tank) between the widget's min and max.
class HmiBar extends ConsumerWidget {
  const HmiBar({super.key, required this.widget});

  final HmiWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(runtimeProvider.select((s) => s.word(WordAddress.parse(widget.address))));
    final fraction = ((value - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 56,
        height: 120,
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          border: Border.all(color: Colors.black54, width: 2),
        ),
        child: FractionallySizedBox(
          heightFactor: fraction,
          widthFactor: 1,
          child: ColoredBox(key: ValueKey('bar-fill-${widget.id}'), color: Colors.blue.shade400),
        ),
      ),
      Text('$value'),
    ]);
  }
}

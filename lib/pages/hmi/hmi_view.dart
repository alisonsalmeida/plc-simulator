import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/hmi.controller.dart';
import 'components/hmi_frame.dart';
import 'components/hmi_palette.dart';

/// Supervisório: a palette and a free canvas of widgets bound to the data table.
class HmiView extends ConsumerWidget {
  const HmiView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final widgets = ref.watch(hmiProvider.select((s) => s.widgets));
    return Column(children: [
      const HmiPalette(),
      const Divider(height: 1),
      Expanded(
        child: ClipRect(
          child: ColoredBox(
            color: Colors.blueGrey.shade50,
            child: Stack(children: [
              const SizedBox.expand(),
              for (final w in widgets) HmiFrame(key: ValueKey('hmi-${w.id}'), widget: w),
            ]),
          ),
        ),
      ),
    ]);
  }
}

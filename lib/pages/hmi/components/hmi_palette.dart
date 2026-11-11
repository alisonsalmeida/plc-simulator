import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/hmi.controller.dart';
import '../../../models/hmi_state.model.dart';
import 'hmi_widget_dialog.dart';

/// Row of buttons that add a widget of each kind to the canvas.
class HmiPalette extends ConsumerWidget {
  const HmiPalette({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(spacing: 8, children: [
          for (final kind in HmiKind.values)
            OutlinedButton(
              key: ValueKey('palette-${kind.name}'),
              onPressed: () => showHmiWidgetDialog(
                context,
                kind: kind,
                submit: (address, label, min, max) =>
                    ref.read(hmiProvider.notifier).add(kind, address, label: label, min: min, max: max),
              ),
              child: Text(kind.label),
            ),
        ]),
      );
}

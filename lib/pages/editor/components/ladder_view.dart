import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/runtime_state.model.dart';
import 'rung_view.dart';

/// Self-contained ladder editor/monitor pane: all rungs plus the END rung, scrollable in
/// both directions. It only reads the providers, so it can live in any container.
class LadderView extends ConsumerWidget {
  const LadderView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(programProvider);
    final program = state.program;
    final runtime = ref.watch(runtimeProvider);
    final enabled = runtime.mode == RuntimeMode.stop;
    final edit = ref.read(rungEditProvider.notifier);
    return LayoutBuilder(
      builder: (_, c) {
        var width = c.maxWidth - 16;
        for (final r in program.rungs) {
          final w = rungMinWidth(r);
          if (w > width) width = w;
        }
        if (endRungMinWidth > width) width = endRungMinWidth;
        final n = program.rungs.length;
        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width + 16,
              child: ListView(
                padding: const EdgeInsets.all(8),
                children: [
                  for (var i = 0; i < n; i++) ...[
                    RungGap(enabled: enabled, onDrop: () => edit.insertRung(i)),
                    RungView(
                      index: i,
                      rung: program.rungs[i],
                      program: program,
                      runtime: runtime,
                      selected: state.selectedRung == i,
                    ),
                  ],
                  RungGap(enabled: enabled, onDrop: () => edit.insertRung(n)),
                  EndRungView(number: n),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

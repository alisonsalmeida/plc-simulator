import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/runtime_state.model.dart';
import 'rung_view.dart';

/// Self-contained ladder editor/monitor pane: all rungs plus the END rung, scrollable in
/// both directions. It only reads the providers, so it can live in any container.
class LadderView extends ConsumerStatefulWidget {
  const LadderView({super.key});

  @override
  ConsumerState<LadderView> createState() => _LadderViewState();
}

class _LadderViewState extends ConsumerState<LadderView> {
  final _hController = ScrollController();

  @override
  void dispose() {
    _hController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(programProvider);
    // The view works on the active routine: its rungs stand in for the main rungs.
    final program = state.program.copyWith(rungs: state.rungs);
    final routine = state.activeRoutine;
    final live = ref.watch(runtimeProvider);
    final runtime = routine == 2
        ? live
        : live.copyWith(powerFlow: live.subroutineFlow[routine] ?? const []);
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
          controller: _hController,
          child: SingleChildScrollView(
            controller: _hController,
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/data_table.controller.dart';
import '../../controllers/main_view.controller.dart';
import '../../models/hmi_state.model.dart';
import '../hmi/hmi_view.dart';
import '../../controllers/runtime.controller.dart';
import '../../models/runtime_state.model.dart';
import '../../controllers/rung_edit.controller.dart';
import '../data_table/data_table_window.dart';
import 'components/app_menu_bar.dart';
import 'components/io_panel.dart';
import 'components/instruction_toolbar.dart';
import 'components/ladder_view.dart';
import 'components/pane_splitter.dart';
import 'components/run_toolbar.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataOpen = ref.watch(dataTableProvider.select((s) => s.open));
    final toolbarAndLadder = Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final stopped = ref.read(runtimeProvider).mode == RuntimeMode.stop;
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.delete && stopped) {
          ref.read(rungEditProvider.notifier).deleteSelectedRung();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: const Column(
        children: [
          InstructionToolbar(),
          Expanded(child: LadderView()),
        ],
      ),
    );
    // The Data Files window sits outside the Focus so the Delete key never reaches it.
    final hmi = ref.watch(mainViewProvider) == MainView.hmi;
    final ladder = hmi
        ? const HmiView()
        : LayoutBuilder(
            builder: (_, c) {
              if (!dataOpen) return toolbarAndLadder;
              final total = c.maxHeight;
              final fraction = ref.watch(dataTableProvider.select((s) => s.heightFraction));
              final paneHeight = (total - PaneSplitter.thickness) * fraction;
              return Column(
                children: [
                  Expanded(child: toolbarAndLadder),
                  PaneSplitter(
                    onDrag: (dy) => ref
                        .read(dataTableProvider.notifier)
                        .setHeightFraction((paneHeight - dy) / (total - PaneSplitter.thickness)),
                  ),
                  SizedBox(height: paneHeight, child: const DataTableWindow()),
                ],
              );
            },
          );
    return Scaffold(
      body: Column(
        children: [
          const AppMenuBar(),
          const RunToolbar(),
          Expanded(
            child: LayoutBuilder(
              builder: (_, c) => c.maxWidth >= 900
                  ? Row(
                      children: [
                        Expanded(child: ladder),
                        const VerticalDivider(width: 1),
                        const SizedBox(width: 340, child: IoPanel()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: ladder),
                        const Divider(height: 1),
                        const SizedBox(height: 300, child: IoPanel()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

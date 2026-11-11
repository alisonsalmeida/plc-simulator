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
import '../../controllers/find_replace.controller.dart';
import '../../controllers/project_tree.controller.dart';
import 'components/app_menu_bar.dart';
import 'components/chassis_view.dart';
import 'components/find_replace_dialog.dart';
import 'components/io_panel.dart';
import 'components/project_tree.dart';
import 'components/status_bar.dart';
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
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.delete &&
            stopped) {
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
    final view = ref.watch(mainViewProvider);
    final content = view == MainView.chassis
        ? const ChassisConfigView()
        : view == MainView.hmi
        ? const HmiView()
        : LayoutBuilder(
            builder: (_, c) {
              if (!dataOpen) return toolbarAndLadder;
              final total = c.maxHeight;
              final fraction = ref.watch(
                dataTableProvider.select((s) => s.heightFraction),
              );
              final paneHeight = (total - PaneSplitter.thickness) * fraction;
              return Column(
                children: [
                  Expanded(child: toolbarAndLadder),
                  PaneSplitter(
                    onDrag: (dy) => ref
                        .read(dataTableProvider.notifier)
                        .setHeightFraction(
                          (paneHeight - dy) / (total - PaneSplitter.thickness),
                        ),
                  ),
                  SizedBox(height: paneHeight, child: const DataTableWindow()),
                ],
              );
            },
          );
    final ladder = Column(
      children: [
        _ViewTabs(view: view),
        Expanded(child: content),
      ],
    );
    final treeOpen = ref.watch(projectTreeProvider.select((s) => s.isOpen));
    final findOpen = ref.watch(findReplaceProvider.select((s) => s.isOpen));
    final main = treeOpen
        ? Row(
            children: [
              const ProjectTree(),
              const VerticalDivider(width: 1),
              Expanded(child: ladder),
            ],
          )
        : ladder;
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              const AppMenuBar(),
              const RunToolbar(),
              Expanded(
                child: LayoutBuilder(
                  builder: (_, c) => c.maxWidth >= 900
                      ? Row(
                          children: [
                            Expanded(child: main),
                            const VerticalDivider(width: 1),
                            const SizedBox(width: 340, child: IoPanel()),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(child: main),
                            const Divider(height: 1),
                            const SizedBox(height: 300, child: IoPanel()),
                          ],
                        ),
                ),
              ),
              const StatusBar(),
            ],
          ),
          if (findOpen)
            const Positioned(top: 90, right: 360, child: FindReplaceDialog()),
        ],
      ),
    );
  }
}

/// Tab row above the main area: ladder, Supervisório and the chassis configuration.
class _ViewTabs extends ConsumerWidget {
  const _ViewTabs({required this.view});

  final MainView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget tab(MainView value, String label) => InkWell(
      key: ValueKey('view-tab-${value.name}'),
      onTap: () => ref.read(mainViewProvider.notifier).select(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: view == value ? Colors.white : Colors.black12,
          border: Border(
            top: BorderSide(color: view == value ? Colors.blue : Colors.black26, width: 2),
            right: const BorderSide(color: Colors.black26),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: view == value ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
    return Row(
      children: [
        tab(MainView.ladder, 'LAD 2 - MAIN'),
        // tab(MainView.hmi, 'IHM - Supervisório'),
        tab(MainView.chassis, 'Chassi - Configuração de E/S'),
      ],
    );
  }
}

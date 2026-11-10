import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/runtime.controller.dart';
import '../../models/runtime_state.model.dart';
import '../../controllers/rung_edit.controller.dart';
import 'components/io_panel.dart';
import 'components/instruction_toolbar.dart';
import 'components/ladder_view.dart';
import 'components/run_toolbar.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ladder = Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        final stopped = ref.read(runtimeProvider).mode == RuntimeMode.stop;
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.delete && stopped) {
          ref.read(rungEditProvider.notifier).deleteSelectedRung();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: const Column(children: [
        InstructionToolbar(),
        Expanded(child: LadderView()),
      ]),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador CLP'), actions: const [RunToolbar()]),
      body: LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 900
            ? Row(children: [
                Expanded(child: ladder),
                const VerticalDivider(width: 1),
                const SizedBox(width: 340, child: IoPanel()),
              ])
            : Column(children: [
                Expanded(child: ladder),
                const Divider(height: 1),
                const SizedBox(height: 300, child: IoPanel()),
              ]),
      ),
    );
  }
}

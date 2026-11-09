import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/program.controller.dart';
import '../../controllers/runtime.controller.dart';
import '../../models/runtime_state.model.dart';
import 'components/io_panel.dart';
import 'components/run_toolbar.dart';
import 'components/rung_view.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider.select((s) => s.example.program));
    final runtime = ref.watch(runtimeProvider);
    final rungs = ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: program.rungs.length,
      itemBuilder: (_, i) => RungView(
        index: i,
        rung: program.rungs[i],
        program: program,
        trace: i < runtime.powerFlow.length ? runtime.powerFlow[i] : const [],
        online: runtime.mode != RuntimeMode.stop,
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador CLP'), actions: const [RunToolbar()]),
      body: LayoutBuilder(
        builder: (_, c) => c.maxWidth >= 900
            ? Row(children: [
                Expanded(child: rungs),
                const VerticalDivider(width: 1),
                const SizedBox(width: 340, child: IoPanel()),
              ])
            : Column(children: [
                Expanded(child: rungs),
                const Divider(height: 1),
                const SizedBox(height: 300, child: IoPanel()),
              ]),
      ),
    );
  }
}

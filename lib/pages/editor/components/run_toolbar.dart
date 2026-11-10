import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/program_file.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/program_file_result.model.dart';
import '../../../models/runtime_state.model.dart';

/// Example picker and RUN / STEP / STOP controls.
class RunToolbar extends ConsumerWidget {
  const RunToolbar({super.key});

  static const _modeLabels = {
    RuntimeMode.stop: 'STOP',
    RuntimeMode.run: 'RUN',
    RuntimeMode.step: 'PASSO',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programProvider);
    final mode = ref.watch(runtimeProvider.select((s) => s.mode));
    final scans = ref.watch(runtimeProvider.select((s) => s.scanCount));
    final runtime = ref.read(runtimeProvider.notifier);
    return Row(children: [
      DropdownButton<int>(
        value: programs.selected,
        underline: const SizedBox.shrink(),
        items: [
          for (var i = 0; i < programs.examples.length; i++)
            DropdownMenuItem(value: i, child: Text(programs.examples[i].name)),
        ],
        onChanged: (i) => ref.read(programProvider.notifier).select(i!),
      ),
      const SizedBox(width: 8),
      TextButton.icon(
        icon: const Icon(Icons.folder_open),
        label: const Text('Abrir'),
        onPressed: () => _report(context, ref.read(programFileProvider.notifier).open()),
      ),
      TextButton.icon(
        icon: const Icon(Icons.save),
        label: const Text('Salvar'),
        onPressed: () => _report(context, ref.read(programFileProvider.notifier).save()),
      ),
      const SizedBox(width: 8),
      Chip(
        label: Text('${_modeLabels[mode]} · $scans varreduras'),
        backgroundColor: mode == RuntimeMode.stop ? null : Colors.green.shade100,
      ),
      IconButton(
        tooltip: 'RUN',
        icon: const Icon(Icons.play_arrow),
        onPressed: mode == RuntimeMode.run ? null : runtime.run,
      ),
      IconButton(tooltip: 'Uma varredura', icon: const Icon(Icons.skip_next), onPressed: runtime.step),
      IconButton(
        tooltip: 'STOP',
        icon: const Icon(Icons.stop),
        onPressed: mode == RuntimeMode.stop ? null : runtime.stop,
      ),
      const SizedBox(width: 8),
    ]);
  }

  /// Shows the outcome of a file action in a SnackBar (nothing when the user cancelled).
  Future<void> _report(BuildContext context, Future<ProgramFileResult> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action;
    if (result.status == ProgramFileStatus.cancelled) return;
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }
}

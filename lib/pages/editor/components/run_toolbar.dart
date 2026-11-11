import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_table.controller.dart';
import '../../../controllers/main_view.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/program_file.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';
import '../../../models/program_file_result.model.dart';
import '../../../models/runtime_state.model.dart';
import 'app_menu_bar.dart' show desktopBorder, desktopGray;

/// Desktop toolbar: file icons, RUN / STEP / STOP, view tabs, Data Files and example picker.
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
    final view = ref.watch(mainViewProvider);
    final dataOpen = ref.watch(dataTableProvider.select((s) => s.open));
    final running = mode != RuntimeMode.stop;
    return Container(
      height: 38,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: desktopGray,
        border: Border(bottom: BorderSide(color: desktopBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const SizedBox(width: 4),
          _icon(Icons.note_add_outlined, 'Novo', () => ref.read(programProvider.notifier).loadProgram(const Program([]))),
          _icon(Icons.folder_open_outlined, 'Abrir', () => _report(context, ref.read(programFileProvider.notifier).open())),
          _icon(Icons.save_outlined, 'Salvar', () => _report(context, ref.read(programFileProvider.notifier).save())),
          _separator(),
          Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: running ? const Color(0xFFB7E4B7) : const Color(0xFFE4E1DA),
              border: const Border(
                top: BorderSide(color: desktopBorder),
                left: BorderSide(color: desktopBorder),
                bottom: BorderSide(color: Colors.white),
                right: BorderSide(color: Colors.white),
              ),
            ),
            child: Text(
              '${_modeLabels[mode]} · $scans varreduras',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black),
            ),
          ),
          const SizedBox(width: 4),
          _icon(Icons.play_arrow, 'RUN', mode == RuntimeMode.run ? null : runtime.run),
          _icon(Icons.skip_next, 'Uma varredura', runtime.step),
          _icon(Icons.stop, 'STOP', mode == RuntimeMode.stop ? null : runtime.stop),
          _separator(),
          _tab('Ladder', view == MainView.ladder, () => ref.read(mainViewProvider.notifier).select(MainView.ladder)),
          // _tab('Supervisório', view == MainView.hmi, () => ref.read(mainViewProvider.notifier).select(MainView.hmi)),
          _separator(),
          _icon(Icons.table_chart_outlined, 'Data Files', () {
            final table = ref.read(dataTableProvider.notifier);
            dataOpen ? table.hide() : table.show();
          }, selected: dataOpen),
          _separator(),
          SizedBox(
            width: 220,
            child: DropdownButton<int>(
              value: programs.selected,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox.shrink(),
              style: const TextStyle(fontSize: 12, color: Colors.black),
              items: [
                for (var i = 0; i < programs.examples.length; i++)
                  DropdownMenuItem(value: i, child: Text(programs.examples[i].name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (i) => ref.read(programProvider.notifier).select(i!),
            ),
          ),
          const SizedBox(width: 8),
        ]),
      ),
    );
  }

  Widget _icon(IconData icon, String tooltip, VoidCallback? onPressed, {bool selected = false}) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            width: 30,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: selected ? _sunken : null,
            child: Icon(icon, size: 18, color: onPressed == null ? desktopBorder : Colors.black87),
          ),
        ),
      );

  Widget _tab(String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        child: Container(
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: active ? _sunken : _raised,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: active ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      );

  Widget _separator() => Container(
        width: 1,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: desktopBorder,
      );

  static const _sunken = BoxDecoration(
    color: Color(0xFFE4E1DA),
    border: Border(
      top: BorderSide(color: desktopBorder),
      left: BorderSide(color: desktopBorder),
      bottom: BorderSide(color: Colors.white),
      right: BorderSide(color: Colors.white),
    ),
  );

  static const _raised = BoxDecoration(
    border: Border(
      top: BorderSide(color: Colors.white),
      left: BorderSide(color: Colors.white),
      bottom: BorderSide(color: desktopBorder),
      right: BorderSide(color: desktopBorder),
    ),
  );

  /// Shows the outcome of a file action in a SnackBar (nothing when the user cancelled).
  Future<void> _report(BuildContext context, Future<ProgramFileResult> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action;
    if (result.status == ProgramFileStatus.cancelled) return;
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }
}

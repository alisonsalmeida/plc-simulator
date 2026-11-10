import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_table.controller.dart';
import '../../../controllers/main_view.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/program_file.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../models/hmi_state.model.dart';
import '../../../models/program_file_result.model.dart';
import '../../../models/runtime_state.model.dart';

/// Classic Windows desktop chrome colours shared by the menu bar and toolbar.
const desktopGray = Color(0xFFD4D0C8);
const desktopBorder = Color(0xFF808080);

/// RSLogix-style desktop menu bar: Arquivo, Editar, Exibir, Comunicação, Ferramentas and Ajuda.
class AppMenuBar extends ConsumerWidget {
  const AppMenuBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programs = ref.watch(programProvider);
    final mode = ref.watch(runtimeProvider.select((s) => s.mode));
    final view = ref.watch(mainViewProvider);
    final dataOpen = ref.watch(dataTableProvider.select((s) => s.open));
    final runtime = ref.read(runtimeProvider.notifier);
    final stopped = mode == RuntimeMode.stop;
    final compact = ButtonStyle(
      visualDensity: VisualDensity.compact,
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12)),
      foregroundColor: const WidgetStatePropertyAll(Colors.black),
      overlayColor: WidgetStatePropertyAll(Colors.black.withValues(alpha: 0.12)),
      shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
    );
    const flat = WidgetStatePropertyAll(RoundedRectangleBorder());
    return Container(
      width: double.infinity,
      alignment: Alignment.centerLeft,
      decoration: const BoxDecoration(
        color: desktopGray,
        border: Border(bottom: BorderSide(color: desktopBorder)),
      ),
      child: MenuBarTheme(
      data: const MenuBarThemeData(
        style: MenuStyle(
          elevation: WidgetStatePropertyAll(0),
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStatePropertyAll(Colors.transparent),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          shape: flat,
        ),
      ),
      child: MenuTheme(
        data: const MenuThemeData(
          style: MenuStyle(
            visualDensity: VisualDensity.compact,
            elevation: WidgetStatePropertyAll(2),
            backgroundColor: WidgetStatePropertyAll(desktopGray),
            surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 2)),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(side: BorderSide(color: desktopBorder)),
            ),
          ),
        ),
        child: MenuBar(
          style: const MenuStyle(
            elevation: WidgetStatePropertyAll(0),
            shape: flat,
          ),
          children: [
            SubmenuButton(
              style: compact,
              menuChildren: [
                MenuItemButton(
                  style: compact,
                  onPressed: () => ref.read(programProvider.notifier).loadProgram(const Program([])),
                  child: const Text('Novo'),
                ),
                MenuItemButton(
                  style: compact,
                  onPressed: () => _report(context, ref.read(programFileProvider.notifier).open()),
                  child: const Text('Abrir...'),
                ),
                MenuItemButton(
                  style: compact,
                  onPressed: () => _report(context, ref.read(programFileProvider.notifier).save()),
                  child: const Text('Salvar'),
                ),
                SubmenuButton(
                  style: compact,
                  menuChildren: [
                    for (var i = 0; i < programs.examples.length; i++)
                      MenuItemButton(
                        style: compact,
                        onPressed: () => ref.read(programProvider.notifier).select(i),
                        child: Text(programs.examples[i].name),
                      ),
                  ],
                  child: const Text('Exemplos'),
                ),
              ],
              child: const Text('Arquivo'),
            ),
            SubmenuButton(
              style: compact,
              menuChildren: [
                MenuItemButton(
                  style: compact,
                  onPressed: () => ref.read(rungEditProvider.notifier).addRung(),
                  child: const Text('Inserir Linha'),
                ),
                MenuItemButton(
                  style: compact,
                  onPressed: stopped && programs.selectedRung != null
                      ? () => ref.read(rungEditProvider.notifier).deleteSelectedRung()
                      : null,
                  child: const Text('Excluir Linha Selecionada'),
                ),
              ],
              child: const Text('Editar'),
            ),
            SubmenuButton(
              style: compact,
              menuChildren: [
                MenuItemButton(
                  style: compact,
                  leadingIcon: _check(view == MainView.ladder),
                  onPressed: () => ref.read(mainViewProvider.notifier).select(MainView.ladder),
                  child: const Text('Ladder'),
                ),
                MenuItemButton(
                  style: compact,
                  leadingIcon: _check(view == MainView.hmi),
                  onPressed: () => ref.read(mainViewProvider.notifier).select(MainView.hmi),
                  child: const Text('Supervisório'),
                ),
                MenuItemButton(
                  style: compact,
                  leadingIcon: _check(dataOpen),
                  onPressed: () {
                    final table = ref.read(dataTableProvider.notifier);
                    dataOpen ? table.hide() : table.show();
                  },
                  child: const Text('Tabela de Dados (Data Files)'),
                ),
              ],
              child: const Text('Exibir'),
            ),
            SubmenuButton(
              style: compact,
              menuChildren: [
                MenuItemButton(
                  style: compact,
                  onPressed: mode == RuntimeMode.run ? null : runtime.run,
                  child: const Text('RUN'),
                ),
                MenuItemButton(style: compact, onPressed: runtime.step, child: const Text('Passo (Step)')),
                MenuItemButton(
                  style: compact,
                  onPressed: stopped ? null : runtime.stop,
                  child: const Text('STOP'),
                ),
              ],
              child: const Text('Comunicação'),
            ),
            SubmenuButton(
              style: compact,
              menuChildren: [
                // Placeholder: no tools yet, kept to mirror the RSLogix menu layout.
                MenuItemButton(style: compact, onPressed: null, child: const Text('Opções...')),
              ],
              child: const Text('Ferramentas'),
            ),
            SubmenuButton(
              style: compact,
              menuChildren: [
                MenuItemButton(
                  style: compact,
                  onPressed: () => showAboutDialog(
                    context: context,
                    applicationName: 'Simulador CLP',
                    applicationIcon: const Icon(Icons.memory),
                    children: const [Text('Simulador de CLP com editor ladder, tabela de dados e supervisório.')],
                  ),
                  child: const Text('Sobre o Simulador'),
                ),
              ],
              child: const Text('Ajuda'),
            ),
          ],
        ),
      ),
      ),
    );
  }

  /// Fixed-width slot so checked and unchecked items stay aligned.
  Widget _check(bool on) => SizedBox(width: 18, child: on ? const Icon(Icons.check, size: 16) : null);

  /// Shows the outcome of a file action in a SnackBar (nothing when the user cancelled).
  Future<void> _report(BuildContext context, Future<ProgramFileResult> action) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await action;
    if (result.status == ProgramFileStatus.cancelled) return;
    messenger.showSnackBar(SnackBar(content: Text(result.message)));
  }
}

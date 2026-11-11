import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_table.controller.dart';
import '../../../controllers/main_view.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/project_tree.controller.dart';
import '../../../models/hmi_state.model.dart';
import 'app_menu_bar.dart' show desktopBorder, desktopGray;

/// RSLogix-style Project tree: controller, program files, data files and Supervisório.
class ProjectTree extends ConsumerWidget {
  const ProjectTree({super.key});

  static const _dataFiles = [
    (BitFile.output, 'O0 - OUTPUT'),
    (BitFile.input, 'I1 - INPUT'),
    (BitFile.status, 'S2 - STATUS'),
    (BitFile.bit, 'B3 - BINARY'),
    (BitFile.timer, 'T4 - TIMER'),
    (BitFile.counter, 'C5 - COUNTER'),
    (BitFile.control, 'R6 - CONTROL'),
    (BitFile.integer, 'N7 - INTEGER'),
    (BitFile.float, 'F8 - FLOAT'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = ref.watch(projectTreeProvider.select((s) => s.width));
    final name = ref
        .watch(programProvider.select((s) => s.example.name))
        .toUpperCase();
    final subroutines = ref.watch(
      programProvider.select((s) => s.program.subroutines.keys.toList()..sort()),
    );
    void openRoutine(int file) {
      ref.read(programProvider.notifier).setActiveRoutine(file);
      ref.read(mainViewProvider.notifier).select(MainView.ladder);
    }

    void showFile(BitFile f) {
      ref.read(dataTableProvider.notifier)
        ..selectFile(f)
        ..show();
    }

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: desktopGray,
        border: Border(
          top: BorderSide(color: desktopBorder, width: 2),
          left: BorderSide(color: desktopBorder, width: 2),
          bottom: BorderSide(color: Colors.white, width: 2),
          right: BorderSide(color: Colors.white, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 22,
            color: const Color(0xFF000080),
            padding: const EdgeInsets.only(left: 6),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Projeto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('tree-close'),
                  tooltip: 'Fechar',
                  padding: EdgeInsets.zero,
                  iconSize: 14,
                  constraints: const BoxConstraints.tightFor(
                    width: 24,
                    height: 22,
                  ),
                  color: Colors.white,
                  icon: const Icon(Icons.close),
                  onPressed: ref.read(projectTreeProvider.notifier).close,
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView(
                children: [
                  _Folder(
                    label: name,
                    icon: Icons.account_tree_outlined,
                    depth: 0,
                    children: [
                      _Folder(
                        label: 'Controlador',
                        depth: 1,
                        children: [
                          _Leaf(
                            'Propriedades do Controlador',
                            2,
                            onTap: () => _info(
                              context,
                              'Propriedades do Controlador',
                              const [
                                'Controlador: MicroLogix 1400 Emulado',
                                'Tempo de scan: 10 ms',
                              ],
                            ),
                          ),
                          _Leaf(
                            'Status do Processador',
                            2,
                            onTap: () => showFile(BitFile.status),
                          ),
                          _Leaf(
                            'Configuração de E/S',
                            2,
                            onTap: () => ref
                                .read(mainViewProvider.notifier)
                                .select(MainView.chassis),
                          ),
                        ],
                      ),
                      _Folder(
                        label: 'Arquivos de Programa',
                        depth: 1,
                        children: [
                          _Leaf(
                            'LAD 2 - MAIN',
                            2,
                            onTap: () => openRoutine(2),
                          ),
                          for (final file in subroutines)
                            _Leaf(
                              'LAD $file - SUBROUTINE',
                              2,
                              onTap: () => openRoutine(file),
                            ),
                          _Leaf(
                            '+ Adicionar sub-rotina',
                            2,
                            onTap: () {
                              ref.read(programProvider.notifier).addSubroutine();
                              ref.read(mainViewProvider.notifier).select(MainView.ladder);
                            },
                          ),
                        ],
                      ),
                      _Folder(
                        label: 'Arquivos de Dados',
                        depth: 1,
                        children: [
                          for (final (file, label) in _dataFiles)
                            _Leaf(label, 2, onTap: () => showFile(file)),
                        ],
                      ),
                      // _Folder(
                      //   label: 'Supervisório',
                      //   depth: 1,
                      //   children: [
                      //     _Leaf(
                      //       'IHM - Telas',
                      //       2,
                      //       onTap: () => ref
                      //           .read(mainViewProvider.notifier)
                      //           .select(MainView.hmi),
                      //     ),
                      //   ],
                      // ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _info(BuildContext context, String title, List<String> lines) =>
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(title, style: const TextStyle(fontSize: 14)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final l in lines)
                Text(l, style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
}

const _rowStyle = TextStyle(fontSize: 11.5, color: Colors.black);

class _Folder extends StatefulWidget {
  const _Folder({
    required this.label,
    required this.depth,
    required this.children,
    this.icon = Icons.folder,
  });

  final String label;
  final int depth;
  final IconData icon;
  final List<Widget> children;

  @override
  State<_Folder> createState() => _FolderState();
}

class _FolderState extends State<_Folder> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: EdgeInsets.only(
            left: 4.0 + widget.depth * 14,
            top: 2,
            bottom: 2,
          ),
          child: Row(
            children: [
              Icon(
                _expanded ? Icons.expand_more : Icons.chevron_right,
                size: 14,
              ),
              Icon(widget.icon, size: 14, color: const Color(0xFFB8860B)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _rowStyle,
                ),
              ),
            ],
          ),
        ),
      ),
      if (_expanded) ...widget.children,
    ],
  );
}

class _Leaf extends StatelessWidget {
  const _Leaf(this.label, this.depth, {required this.onTap});

  final String label;
  final int depth;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: EdgeInsets.only(left: 4.0 + depth * 14 + 14, top: 2, bottom: 2),
      child: Row(
        children: [
          const Icon(Icons.description_outlined, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _rowStyle,
            ),
          ),
        ],
      ),
    ),
  );
}

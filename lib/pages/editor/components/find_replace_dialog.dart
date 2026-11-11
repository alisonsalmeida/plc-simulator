import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/find_replace.controller.dart';
import '../../../models/find_replace_state.model.dart';
import 'app_menu_bar.dart' show desktopBorder, desktopGray;

/// Floating RSLogix-style "Localizar / Substituir" dialog, shown over the editor.
class FindReplaceDialog extends ConsumerStatefulWidget {
  const FindReplaceDialog({super.key});

  @override
  ConsumerState<FindReplaceDialog> createState() => _FindReplaceDialogState();
}

class _FindReplaceDialogState extends ConsumerState<FindReplaceDialog> {
  late final TextEditingController _query;
  late final TextEditingController _replacement;

  @override
  void initState() {
    super.initState();
    final s = ref.read(findReplaceProvider);
    _query = TextEditingController(text: s.query);
    _replacement = TextEditingController(text: s.replacement);
  }

  @override
  void dispose() {
    _query.dispose();
    _replacement.dispose();
    super.dispose();
  }

  String _feedback(FindReplaceState s) {
    if (s.query.isEmpty) return '';
    if (s.matches.isEmpty) return 'Nenhuma ocorrência encontrada';
    if (s.currentIndex < 0) return '${s.matches.length} encontrados';
    return '${s.currentIndex + 1} de ${s.matches.length} encontrados';
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(findReplaceProvider);
    final c = ref.read(findReplaceProvider.notifier);
    final replace = s.mode == FindMode.replace;
    const label = TextStyle(fontSize: 12, color: Colors.black);
    Widget field(
      String name,
      TextEditingController ctl,
      ValueChanged<String> onChanged, {
      bool enabled = true,
    }) => Row(
      children: [
        SizedBox(width: 90, child: Text(name, style: label)),
        Expanded(
          child: SizedBox(
            height: 24,
            child: TextField(
              key: ValueKey('find-$name'),
              controller: ctl,
              enabled: enabled,
              style: label,
              onChanged: onChanged,
              decoration: const InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
              ),
            ),
          ),
        ),
      ],
    );
    Widget button(String text, VoidCallback? onTap) => SizedBox(
      width: 130,
      height: 24,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: desktopGray,
          foregroundColor: Colors.black,
          padding: EdgeInsets.zero,
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: desktopBorder),
          ),
          textStyle: const TextStyle(fontSize: 12),
        ),
        child: Text(text),
      ),
    );
    return Material(
      color: desktopGray,
      elevation: 6,
      shape: const RoundedRectangleBorder(
        side: BorderSide(color: desktopBorder),
      ),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 24,
              color: const Color(0xFF000080),
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Localizar / Substituir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('find-close'),
                    tooltip: 'Fechar',
                    padding: EdgeInsets.zero,
                    iconSize: 16,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 24,
                    ),
                    color: Colors.white,
                    icon: const Icon(Icons.close),
                    onPressed: c.close,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        field('Localizar:', _query, c.setQuery),
                        const SizedBox(height: 6),
                        field(
                          'Substituir por:',
                          _replacement,
                          c.setReplacement,
                          enabled: replace,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            SizedBox(
                              height: 24,
                              width: 24,
                              child: Checkbox(
                                key: const ValueKey('find-case'),
                                value: s.matchCase,
                                onChanged: (v) => c.setMatchCase(v ?? false),
                              ),
                            ),
                            const Text(
                              'Diferenciar maiúsculas/minúsculas',
                              style: label,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _feedback(s),
                            key: const ValueKey('find-feedback'),
                            style: label,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      button(
                        'Localizar Próximo',
                        s.matches.isEmpty ? null : c.findNext,
                      ),
                      const SizedBox(height: 4),
                      button(
                        'Substituir',
                        replace && s.matches.isNotEmpty
                            ? c.replaceCurrent
                            : null,
                      ),
                      const SizedBox(height: 4),
                      button(
                        'Substituir Tudo',
                        replace && s.matches.isNotEmpty ? c.replaceAll : null,
                      ),
                      const SizedBox(height: 4),
                      button('Fechar', c.close),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

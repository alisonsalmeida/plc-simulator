import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/runtime_state.model.dart';
import 'app_menu_bar.dart' show desktopBorder, desktopGray;

/// Classic Windows status bar at the bottom of the editor.
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(runtimeProvider.select((s) => s.mode));
    final forces = ref.watch(runtimeProvider.select((s) => s.forces.length));
    final rung = ref.watch(programProvider.select((s) => s.selectedRung));
    final running = mode == RuntimeMode.run;
    return Container(
      height: 22,
      color: desktopGray,
      padding: const EdgeInsets.all(1),
      child: Row(
        children: [
          Expanded(
            child: _panel(
              rung == null
                  ? 'Para Ajuda, pressione F1'
                  : 'Linha $rung selecionada',
            ),
          ),
          _panel('Scan: 10 ms', width: 100),
          _panel(
            running ? 'RUN' : 'PROG',
            width: 80,
            color: running ? const Color(0xFF008000) : const Color(0xFF806000),
            bold: true,
          ),
          _panel('REMOTE', width: 80),
          _panel(
            forces > 0 ? 'Forças: $forces ativas' : 'Sem Forçamentos',
            width: 120,
            color: forces > 0 ? const Color(0xFFB05000) : Colors.black,
            bold: forces > 0,
          ),
          _panel('Driver: Emulado', width: 130),
        ],
      ),
    );
  }

  Widget _panel(
    String text, {
    double? width,
    Color color = Colors.black,
    bool bold = false,
  }) => Container(
    width: width,
    margin: const EdgeInsets.only(left: 2),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.centerLeft,
    decoration: const BoxDecoration(
      border: Border(
        top: BorderSide(color: desktopBorder),
        left: BorderSide(color: desktopBorder),
        bottom: BorderSide(color: Colors.white),
        right: BorderSide(color: Colors.white),
      ),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textScaler: TextScaler.noScaling,
      style: TextStyle(
        fontSize: 11,
        color: color,
        fontWeight: bold ? FontWeight.bold : null,
      ),
    ),
  );
}

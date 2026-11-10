import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/runtime_state.model.dart';
import '../../../theme/ladder_assets.dart';

/// Classic grey instruction bar: draggable tools plus the instruction-group tabs.
/// Everything is disabled outside STOP.
class InstructionToolbar extends ConsumerStatefulWidget {
  const InstructionToolbar({super.key});

  @override
  ConsumerState<InstructionToolbar> createState() => _InstructionToolbarState();
}

class _InstructionToolbarState extends ConsumerState<InstructionToolbar> {
  static const _tabs = ['User', 'Bit', 'Timer/Counter', 'Input/Output', 'Compare'];
  static const _enabledTabs = {'User', 'Bit'};
  static const _tools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'XIC': 'XIC – Contato NA',
    'XIO': 'XIO – Contato NF',
    'OTE': 'OTE – Saída (energizar)',
    'OTL': 'OTL – Saída com retenção (latch)',
    'OTU': 'OTU – Desliga retenção (unlatch)',
  };

  String _tab = 'User';

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(runtimeProvider.select((s) => s.mode == RuntimeMode.stop));
    final edit = ref.read(rungEditProvider.notifier);
    final hasSelection = ref.watch(programProvider.select((s) => s.selectedRung != null));
    return Container(
      color: const Color(0xFFD4D0C8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.all(4),
          child: Wrap(spacing: 4, runSpacing: 4, children: [
            Tooltip(
              message: 'New Rung – Nova linha',
              child: Draggable<String>(
                data: LadderAssets.rung,
                maxSimultaneousDrags: enabled ? 1 : 0,
                feedback: Material(
                  elevation: 4,
                  child: _Tile(tool: LadderAssets.rung, enabled: true),
                ),
                child: InkWell(
                  onTap: enabled ? edit.addRung : null,
                  child: _Tile(tool: LadderAssets.rung, enabled: enabled),
                ),
              ),
            ),
            for (final MapEntry(:key, :value) in _tools.entries)
              Tooltip(
                message: value,
                child: Draggable<String>(
                  data: key,
                  maxSimultaneousDrags: enabled ? 1 : 0,
                  feedback: Material(elevation: 4, child: _Tile(tool: key, enabled: true)),
                  childWhenDragging: Opacity(opacity: 0.4, child: _Tile(tool: key, enabled: true)),
                  child: _Tile(tool: key, enabled: enabled),
                ),
              ),
            IconButton(
              tooltip: 'Excluir linha selecionada',
              icon: const Icon(Icons.delete_outline),
              onPressed: enabled && hasSelection ? edit.deleteSelectedRung : null,
            ),
          ]),
        ),
        Row(children: [
          for (final t in _tabs)
            _TabButton(
              label: t,
              selected: t == _tab,
              enabled: _enabledTabs.contains(t),
              onTap: () => setState(() => _tab = t),
            ),
        ]),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.tool, required this.enabled});

  final String tool;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6E0),
          border: Border.all(color: Colors.black38),
        ),
        child: ladderSymbol(
          tool,
          color: enabled ? const Color(0xFF000080) : Colors.black26,
          width: 32,
          height: 26,
        ),
      );
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: selected ? Colors.white : const Color(0xFFD4D0C8),
            border: Border.all(color: Colors.black38),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: enabled ? Colors.black : Colors.black38,
              fontWeight: selected ? FontWeight.bold : null,
            ),
          ),
        ),
      );
}

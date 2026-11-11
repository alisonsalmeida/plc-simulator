import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/data_table.controller.dart';
import '../../../controllers/drag_tool.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../models/drag_data.model.dart';
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
  static const _tabs = ['User', 'Bit', 'Timer/Counter', 'Input/Output', 'Compare', 'Compute/Math', 'Move/Logical', 'Shift/FIFO'];
  static const _enabledTabs = {'User', 'Bit', 'Timer/Counter', 'Compare', 'Compute/Math', 'Move/Logical', 'Shift/FIFO'};
  static const _tools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'XIC': 'XIC – Contato NA',
    'XIO': 'XIO – Contato NF',
    'OTE': 'OTE – Saída (energizar)',
    'OTL': 'OTL – Saída com retenção (latch)',
    'OTU': 'OTU – Desliga retenção (unlatch)',
    'ONS': 'ONS – Pulso de borda de subida',
  };
  static const _timerCounterTools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'TON': 'TON – Temporizador na energização',
    'TOF': 'TOF – Temporizador na desenergização',
    'RTO': 'RTO – Temporizador retentivo',
    'CTU': 'CTU – Contador crescente',
    'CTD': 'CTD – Contador decrescente',
    'RES': 'RES – Reset',
  };
  static const _moveTools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'MOV': 'MOV – Mover',
    'MVM': 'MVM – Mover com máscara',
    'CLR': 'CLR – Zerar',
    'AND': 'AND – E bit a bit',
    'OR': 'OR – OU bit a bit',
    'XOR': 'XOR – OU exclusivo bit a bit',
    'NOT': 'NOT – Inverter bits',
    'SWP': 'SWP – Trocar bytes',
    'TOD': 'TOD – Converter para BCD',
    'FRD': 'FRD – Converter de BCD',
  };

  static const _shiftTools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'BSL': 'BSL – Deslocar bits à esquerda',
    'BSR': 'BSR – Deslocar bits à direita',
    'FFL': 'FFL – Carregar fila FIFO',
    'FFU': 'FFU – Descarregar fila FIFO',
    'LFL': 'LFL – Carregar pilha LIFO',
    'LFU': 'LFU – Descarregar pilha LIFO',
  };

  static const _compareTools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'EQU': 'EQU – Igual',
    'NEQ': 'NEQ – Diferente',
    'LES': 'LES – Menor que',
    'LEQ': 'LEQ – Menor ou igual',
    'GRT': 'GRT – Maior que',
    'GEQ': 'GEQ – Maior ou igual',
    'LIM': 'LIM – Teste de limite',
  };

  static const _mathTools = {
    LadderAssets.branch: 'BRANCH – Ramo paralelo',
    'ADD': 'ADD – Somar',
    'SUB': 'SUB – Subtrair',
    'MUL': 'MUL – Multiplicar',
    'DIV': 'DIV – Dividir',
    'NEG': 'NEG – Negar',
    'SQR': 'SQR – Raiz quadrada',
    'SCL': 'SCL – Escalonar',
    'MOD': 'MOD – Resto da divisão',
    'XPY': 'XPY – Potência X^Y',
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
              child: Draggable<RungDragData>(
                data: const RungDragData(tool: LadderAssets.rung),
                maxSimultaneousDrags: enabled ? 1 : 0,
                onDragStarted: () => ref.read(dragToolProvider.notifier).start(LadderAssets.rung),
                onDragEnd: (_) => ref.read(dragToolProvider.notifier).stop(),
                onDraggableCanceled: (_, _) => ref.read(dragToolProvider.notifier).stop(),
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
            for (final MapEntry(:key, :value) in (switch (_tab) {
              'Timer/Counter' => _timerCounterTools,
              'Compare' => _compareTools,
              'Compute/Math' => _mathTools,
              'Move/Logical' => _moveTools,
              'Shift/FIFO' => _shiftTools,
              _ => _tools,
            }).entries)
              Tooltip(
                message: value,
                child: Draggable<RungDragData>(
                  data: RungDragData(tool: key),
                  maxSimultaneousDrags: enabled ? 1 : 0,
                  onDragStarted: () => ref.read(dragToolProvider.notifier).start(key),
                  onDragEnd: (_) => ref.read(dragToolProvider.notifier).stop(),
                  onDraggableCanceled: (_, _) => ref.read(dragToolProvider.notifier).stop(),
                  feedback: Material(elevation: 4, child: _Tile(tool: key, enabled: true)),
                  childWhenDragging: Opacity(opacity: 0.4, child: _Tile(tool: key, enabled: true)),
                  child: _Tile(tool: key, enabled: enabled),
                ),
              ),
            TextButton(
              onPressed: ref.read(dataTableProvider.notifier).show,
              child: const Text('Data Files'),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/io_panel.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/io_panel_state.model.dart';
import '../../../theme/app_theme.dart';

/// Virtual I/O: 16 input switches/push buttons and 16 output lamps.
class IoPanel extends ConsumerWidget {
  const IoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider.select((s) => s.example.program));
    final runtime = ref.watch(runtimeProvider);
    final kinds = ref.watch(ioPanelProvider).kinds;
    final title = Theme.of(context).textTheme.titleSmall;
    String? symbol(BitFile f, int bit) => program.symbolFor(BitAddress(f, 0, bit));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Text('Entradas (I:0)', style: title),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var bit = 0; bit < 16; bit++)
          _InputTile(
            bit: bit,
            symbol: symbol(BitFile.input, bit),
            kind: kinds[bit],
            on: runtime.input(bit),
          ),
      ]),
      const SizedBox(height: 16),
      Text('Saídas (O:0)', style: title),
      const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var bit = 0; bit < 16; bit++)
          _Tile(
            address: 'O:0/$bit',
            symbol: symbol(BitFile.output, bit),
            icon: Icon(Icons.lightbulb,
                size: 32,
                color: runtime.output(bit) ? AppColors.lampOn : AppColors.lampOff),
          ),
      ]),
    ]);
  }
}

class _InputTile extends ConsumerWidget {
  const _InputTile({required this.bit, required this.symbol, required this.kind, required this.on});

  final int bit;
  final String? symbol;
  final InputKind kind;
  final bool on;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.read(runtimeProvider.notifier);
    final momentary = kind == InputKind.momentary;
    final input = GestureDetector(
      onTap: momentary ? null : () => runtime.setInput(bit, !on),
      onTapDown: momentary ? (_) => runtime.setInput(bit, true) : null,
      onTapUp: momentary ? (_) => runtime.setInput(bit, false) : null,
      onTapCancel: momentary ? () => runtime.setInput(bit, false) : null,
      child: Icon(
        momentary ? Icons.radio_button_checked : (on ? Icons.toggle_on : Icons.toggle_off),
        size: 32,
        color: on ? AppColors.energized : AppColors.wire,
      ),
    );
    final kindButton = InkWell(
      onTap: () {
        runtime.setInput(bit, false);
        ref.read(ioPanelProvider.notifier).toggleKind(bit);
      },
      child: Text(momentary ? 'botão' : 'chave',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(decoration: TextDecoration.underline)),
    );
    return _Tile(address: 'I:0/$bit', symbol: symbol, icon: input, active: on, footer: kindButton);
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.address,
    required this.symbol,
    required this.icon,
    this.active = false,
    this.footer,
  });

  final String address;
  final String? symbol;
  final Widget icon;
  final bool active;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: active ? AppColors.energized.withValues(alpha: 0.25) : null,
        border: Border.all(color: active ? AppColors.energized : Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        icon,
        Text(address, style: small),
        Text(symbol ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ?footer,
      ]),
    );
  }
}

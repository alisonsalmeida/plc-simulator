import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/io_panel.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/io_panel_state.model.dart';
import '../../../theme/app_theme.dart';
import 'analog_input_tile.dart';
import 'analog_output_tile.dart';

/// Virtual I/O: 16 input switches/push buttons and 16 output lamps.
class IoPanel extends ConsumerWidget {
  const IoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider.select((s) => s.program));
    final runtime = ref.watch(runtimeProvider);
    final kinds = ref.watch(ioPanelProvider).kinds;
    final title = Theme.of(context).textTheme.titleSmall;
    String? symbol(BitFile f, int bit) => program.symbolFor(BitAddress(f, 0, bit));
    final tab = ref.watch(ioPanelTabProvider);
    final tabs = _IoTabs(
      tab: tab,
      onSelect: ref.read(ioPanelTabProvider.notifier).select,
    );
    if (tab == IoPanelTab.analog) {
      return ListView(padding: const EdgeInsets.all(12), children: [
        tabs,
        const SizedBox(height: 12),
        Text('Entradas analógicas (I:$analogInputSlot)', style: title),
        const SizedBox(height: 8),
        for (var ch = 0; ch < analogInputChannels; ch++) AnalogInputTile(channel: ch),
        const SizedBox(height: 10),
        Text('Saídas analógicas (O:$analogOutputSlot)', style: title),
        const SizedBox(height: 8),
        for (var ch = 0; ch < analogOutputChannels; ch++) AnalogOutputTile(channel: ch),
      ]);
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      tabs,
      const SizedBox(height: 12),
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
            active: runtime.output(bit),
            activeColor: AppColors.lampOn,
            icon: Icon(Icons.lightbulb,
                size: 32,
                color: runtime.output(bit) ? AppColors.lampOn : AppColors.lampOff,
                shadows: runtime.output(bit)
                    ? const [Shadow(color: AppColors.lampOn, blurRadius: 14)]
                    : null),
          ),
      ]),
    ]);
  }
}

/// Desktop-style tab strip switching between digital and analog I/O.
class _IoTabs extends StatelessWidget {
  const _IoTabs({required this.tab, required this.onSelect});

  final IoPanelTab tab;
  final ValueChanged<IoPanelTab> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget button(IoPanelTab value, String label, String key) {
      final selected = tab == value;
      return Expanded(
        child: InkWell(
          key: ValueKey(key),
          onTap: () => onSelect(value),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.black12,
              border: Border(
                top: BorderSide(color: selected ? AppColors.energized : Colors.black26, width: 2),
                left: const BorderSide(color: Colors.black26),
                right: const BorderSide(color: Colors.black26),
              ),
            ),
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
          ),
        ),
      );
    }

    return Row(children: [
      button(IoPanelTab.digital, 'Digitais', 'io-tab-digital'),
      button(IoPanelTab.analog, 'Analógicas', 'io-tab-analog'),
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
    this.activeColor = AppColors.energized,
    this.footer,
  });

  final String address;
  final String? symbol;
  final Widget icon;
  final bool active;
  final Color activeColor;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      decoration: BoxDecoration(
        color: active ? activeColor.withValues(alpha: 0.25) : null,
        border: Border.all(color: active ? activeColor : Colors.black26, width: active ? 2 : 1),
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

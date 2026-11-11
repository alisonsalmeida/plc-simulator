import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/io_panel.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/io_panel_state.model.dart';
import '../../../models/runtime_state.model.dart';
import '../../../theme/app_theme.dart';
import 'analog_input_tile.dart';
import 'analog_output_tile.dart';
import 'seven_segment_tile.dart';
import 'thumbwheel_tile.dart';

/// Virtual I/O: 16 input switches/push buttons and 16 output lamps.
class IoPanel extends ConsumerWidget {
  const IoPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final program = ref.watch(programProvider.select((s) => s.program));
    final runtime = ref.watch(runtimeProvider);
    final kinds = ref.watch(ioPanelProvider).kinds;
    final title = Theme.of(context).textTheme.titleSmall;
    String? symbol(BitFile f, int bit) =>
        program.symbolFor(BitAddress(f, 0, bit));
    final tab = ref.watch(ioPanelTabProvider);
    final tabs = _IoTabs(
      tab: tab,
      onSelect: ref.read(ioPanelTabProvider.notifier).select,
    );
    final chassis = program.chassis;
    if (tab == IoPanelTab.analog) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tabs,
          for (var s = 0; s < chassis.slots.length; s++) ...[
            if (chassis.moduleAt(s).hasAnalogInputs) ...[
              const SizedBox(height: 10),
              Text(
                s == analogInputSlot
                    ? 'Entradas analógicas (I:$s)'
                    : 'Entradas analógicas Slot $s (I:$s)',
                style: title,
              ),
              const SizedBox(height: 8),
              for (
                var ch = 0;
                ch < chassis.moduleAt(s).analogInputChannels;
                ch++
              )
                _analogInput(s, ch),
            ],
            if (chassis.moduleAt(s).hasAnalogOutputs) ...[
              const SizedBox(height: 10),
              Text(
                s == analogOutputSlot
                    ? 'Saídas analógicas (O:$s)'
                    : 'Saídas analógicas Slot $s (O:$s)',
                style: title,
              ),
              const SizedBox(height: 8),
              for (
                var ch = 0;
                ch < chassis.moduleAt(s).analogOutputChannels;
                ch++
              )
                _analogOutput(s, ch),
            ],
          ],
        ],
      );
    }
    if (tab == IoPanelTab.peripherals) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tabs,
          const SizedBox(height: 12),
          Text('Thumbwheel (I:0)', style: title),
          const SizedBox(height: 8),
          const ThumbwheelTile(),
          const SizedBox(height: 16),
          Text('Display 7 segmentos (O:0)', style: title),
          const SizedBox(height: 8),
          const SevenSegmentTile(),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        tabs,
        for (var s = 0; s < chassis.slots.length; s++) ...[
          if (chassis.moduleAt(s).hasDigitalInputs) ...[
            const SizedBox(height: 12),
            Text(
              s == 0 ? 'Entradas (I:0)' : 'Entradas Slot $s (I:$s)',
              style: title,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (
                  var bit = 0;
                  bit < chassis.moduleAt(s).digitalInputBits;
                  bit++
                )
                  if (s == 0)
                    _InputTile(
                      bit: bit,
                      symbol: symbol(BitFile.input, bit),
                      kind: kinds[bit],
                      on: runtime.input(bit),
                      forced:
                          runtime.forceOf(BitAddress(BitFile.input, 0, bit)) !=
                          null,
                    )
                  else
                    _SlotInputTile(
                      slot: s,
                      bit: bit,
                      program: program,
                      runtime: runtime,
                    ),
              ],
            ),
          ],
          if (chassis.moduleAt(s).hasDigitalOutputs) ...[
            const SizedBox(height: 16),
            Text(
              s == 0 ? 'Saídas (O:0)' : 'Saídas Slot $s (O:$s)',
              style: title,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (
                  var bit = 0;
                  bit < chassis.moduleAt(s).digitalOutputBits;
                  bit++
                )
                  _outputTile(s, bit, program, runtime),
              ],
            ),
          ],
        ],
      ],
    );
  }

  Widget _analogInput(int slot, int ch) {
    final element = ioElement(BitFile.input, slot, ch);
    if (element != null && element >= 1 && element <= 4) {
      return AnalogInputTile(channel: element - 1);
    }
    return _RawAnalogTile(file: BitFile.input, slot: slot, channel: ch);
  }

  Widget _analogOutput(int slot, int ch) {
    final element = ioElement(BitFile.output, slot, ch);
    if (element != null && element >= 1 && element <= 2) {
      return AnalogOutputTile(channel: element - 1);
    }
    return _RawAnalogTile(file: BitFile.output, slot: slot, channel: ch);
  }

  Widget _outputTile(int slot, int bit, Program program, RuntimeState runtime) {
    final element = ioElement(BitFile.output, slot, null)!;
    final address = BitAddress(BitFile.output, element, bit);
    final on = slot == 0
        ? runtime.output(bit)
        : runtime.mode != RuntimeMode.stop &&
              ((runtime.data[BitFile.output]?[element] ?? 0) >> bit) & 1 == 1;
    return _Tile(
      address: 'O:$slot/$bit',
      symbol: program.symbolFor(address),
      active: on,
      forced: runtime.forceOf(address) != null,
      activeColor: AppColors.lampOn,
      icon: Icon(
        Icons.lightbulb,
        size: 32,
        color: on ? AppColors.lampOn : AppColors.lampOff,
        shadows: on
            ? const [Shadow(color: AppColors.lampOn, blurRadius: 14)]
            : null,
      ),
    );
  }
}

/// A toggle input of a digital module in slot >= 1, backed directly by the data table.
class _SlotInputTile extends ConsumerWidget {
  const _SlotInputTile({
    required this.slot,
    required this.bit,
    required this.program,
    required this.runtime,
  });

  final int slot;
  final int bit;
  final Program program;
  final RuntimeState runtime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = BitAddress(
      BitFile.input,
      ioElement(BitFile.input, slot, null)!,
      bit,
    );
    final on =
        ((runtime.data[BitFile.input]?[address.word] ?? 0) >> bit) & 1 == 1;
    return _Tile(
      address: 'I:$slot/$bit',
      symbol: program.symbolFor(address),
      active: on,
      forced: runtime.forceOf(address) != null,
      icon: GestureDetector(
        onTap: () => ref.read(runtimeProvider.notifier).setBit(address, !on),
        child: Icon(
          on ? Icons.toggle_on : Icons.toggle_off,
          size: 32,
          color: on ? AppColors.energized : AppColors.wire,
        ),
      ),
    );
  }
}

/// Generic analog channel outside the legacy I:1.0..3 / O:2.0..1: raw 0..32767 slider (input)
/// or read-out (output) over the data table word.
class _RawAnalogTile extends ConsumerWidget {
  const _RawAnalogTile({
    required this.file,
    required this.slot,
    required this.channel,
  });

  final BitFile file;
  final int slot;
  final int channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final element = ioElement(file, slot, channel);
    if (element == null) return const SizedBox.shrink();
    final isInput = file == BitFile.input;
    final raw = ref.watch(
      runtimeProvider.select((s) => s.data[file]?[element] ?? 0),
    );
    final label = '${isInput ? 'I' : 'O'}:$slot.$channel';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(
            child: isInput
                ? Slider(
                    key: ValueKey('raw-analog-$label'),
                    value: raw.clamp(0, 32767).toDouble(),
                    max: 32767,
                    onChanged: (v) => ref
                        .read(runtimeProvider.notifier)
                        .writeWord(WordAddress(file, element), v.round()),
                  )
                : LinearProgressIndicator(value: raw.clamp(0, 32767) / 32767),
          ),
          SizedBox(width: 48, child: Text('$raw', textAlign: TextAlign.end)),
        ],
      ),
    );
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
                top: BorderSide(
                  color: selected ? AppColors.energized : Colors.black26,
                  width: 2,
                ),
                left: const BorderSide(color: Colors.black26),
                right: const BorderSide(color: Colors.black26),
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(IoPanelTab.digital, 'Digitais', 'io-tab-digital'),
        button(IoPanelTab.analog, 'Analógicas', 'io-tab-analog'),
        button(IoPanelTab.peripherals, 'Periféricos', 'io-tab-peripherals'),
      ],
    );
  }
}

class _InputTile extends ConsumerWidget {
  const _InputTile({
    required this.bit,
    required this.symbol,
    required this.kind,
    required this.on,
    required this.forced,
  });

  final int bit;
  final String? symbol;
  final InputKind kind;
  final bool on;
  final bool forced;

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
        momentary
            ? Icons.radio_button_checked
            : (on ? Icons.toggle_on : Icons.toggle_off),
        size: 32,
        color: on ? AppColors.energized : AppColors.wire,
      ),
    );
    final kindButton = InkWell(
      onTap: () {
        runtime.setInput(bit, false);
        ref.read(ioPanelProvider.notifier).toggleKind(bit);
      },
      child: Text(
        momentary ? 'botão' : 'chave',
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(decoration: TextDecoration.underline),
      ),
    );
    return _Tile(
      address: 'I:0/$bit',
      symbol: symbol,
      icon: input,
      active: on,
      forced: forced,
      footer: kindButton,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.address,
    required this.symbol,
    required this.icon,
    this.active = false,
    this.forced = false,
    this.activeColor = AppColors.energized,
    this.footer,
  });

  final String address;
  final String? symbol;
  final Widget icon;
  final bool active;

  /// Shows the amber `[F]` badge: the bit is forced.
  final bool forced;
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
        border: Border.all(
          color: active ? activeColor : Colors.black26,
          width: active ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          Text(address, style: small),
          if (forced)
            Text(
              '[F]',
              style: small?.copyWith(
                color: const Color(0xFFB05000),
                fontWeight: FontWeight.bold,
              ),
            ),
          Text(
            symbol ?? '',
            style: small,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          ?footer,
        ],
      ),
    );
  }
}

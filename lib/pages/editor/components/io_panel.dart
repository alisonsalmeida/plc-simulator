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
    final tab = ref.watch(ioPanelTabProvider);
    final tabs = _IoTabs(
      tab: tab,
      onSelect: ref.read(ioPanelTabProvider.notifier).select,
    );
    final chassis = program.chassis;
    final mapping = program.ioMapping;
    if (tab == IoPanelTab.analog) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          tabs,
          for (var s = 0; s < chassis.slots.length; s++) ...[
            if (chassis.moduleAt(s).hasAnalogInputs) ...[
              _SectionHeader(
                title: s == mapping.analogInputSlot
                    ? 'Entradas analógicas (I:$s)'
                    : 'Entradas analógicas Slot $s (I:$s)',
                style: title,
                topGap: 10,
                picker: s == mapping.analogInputSlot
                    ? _SlotPicker(
                        pickerKey: const ValueKey('analog-input-slot'),
                        value: s,
                        slots: _slots(chassis, (m) => m.hasAnalogInputs),
                        onChanged: ref
                            .read(programProvider.notifier)
                            .setAnalogInputSlot,
                      )
                    : null,
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
              _SectionHeader(
                title: s == mapping.analogOutputSlot
                    ? 'Saídas analógicas (O:$s)'
                    : 'Saídas analógicas Slot $s (O:$s)',
                style: title,
                topGap: 10,
                picker: s == mapping.analogOutputSlot
                    ? _SlotPicker(
                        pickerKey: const ValueKey('analog-output-slot'),
                        value: s,
                        slots: _slots(chassis, (m) => m.hasAnalogOutputs),
                        onChanged: ref
                            .read(programProvider.notifier)
                            .setAnalogOutputSlot,
                      )
                    : null,
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
          Text(
            'Thumbwheel (${program.ioMapping.thumbwheelSlot != null ? 'I:${program.ioMapping.thumbwheelSlot}' : '⊘'})',
            style: title,
          ),
          const SizedBox(height: 8),
          const ThumbwheelTile(),
          const SizedBox(height: 16),
          Text(
            'Display 7 segmentos (${program.ioMapping.sevenSegmentSlot != null ? 'O:${program.ioMapping.sevenSegmentSlot}' : '⊘'})',
            style: title,
          ),
          const SizedBox(height: 8),
          const SevenSegmentTile(),
        ],
      );
    }
    final controller = ref.read(programProvider.notifier);
    final inSlot = mapping.digitalInputSlot;
    final outSlot = mapping.digitalOutputSlot;
    final inModule = chassis.moduleAt(inSlot);
    final outModule = chassis.moduleAt(outSlot);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        tabs,
        const SizedBox(height: 12),
        _SectionHeader(
          title: 'Entradas (I:$inSlot)',
          style: title,
          picker: _SlotPicker(
            pickerKey: const ValueKey('digital-input-slot'),
            value: inSlot,
            slots: _slots(chassis, (m) => m.hasDigitalInputs),
            onChanged: controller.setDigitalInputSlot,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (inModule.hasDigitalInputs)
              for (var bit = 0; bit < inModule.digitalInputBits; bit++)
                _InputTile(
                  slot: inSlot,
                  bit: bit,
                  symbol: program.symbolFor(
                    BitAddress(
                      BitFile.input,
                      ioElement(BitFile.input, inSlot, null)!,
                      bit,
                    ),
                  ),
                  kind: kinds[bit],
                  on: runtime.input(bit),
                  forced:
                      runtime.forceOf(
                        BitAddress(
                          BitFile.input,
                          ioElement(BitFile.input, inSlot, null)!,
                          bit,
                        ),
                      ) !=
                      null,
                ),
          ],
        ),
        _SectionHeader(
          title: 'Saídas (O:$outSlot)',
          style: title,
          topGap: 16,
          picker: _SlotPicker(
            pickerKey: const ValueKey('digital-output-slot'),
            value: outSlot,
            slots: _slots(chassis, (m) => m.hasDigitalOutputs),
            onChanged: controller.setDigitalOutputSlot,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (outModule.hasDigitalOutputs)
              for (var bit = 0; bit < outModule.digitalOutputBits; bit++)
                _outputTile(outSlot, bit, program, runtime),
          ],
        ),
        for (var s = 0; s < chassis.slots.length; s++) ...[
          if (s != inSlot && chassis.moduleAt(s).hasDigitalInputs) ...[
            const SizedBox(height: 12),
            Text('Entradas Slot $s (I:$s)', style: title),
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
                  _SlotInputTile(
                    slot: s,
                    bit: bit,
                    program: program,
                    runtime: runtime,
                  ),
              ],
            ),
          ],
          if (s != outSlot && chassis.moduleAt(s).hasDigitalOutputs) ...[
            const SizedBox(height: 16),
            Text('Saídas Slot $s (O:$s)', style: title),
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

  static List<int> _slots(
    ChassisConfig chassis,
    bool Function(ModuleDefinition) has,
  ) => [
    for (var s = 0; s < chassis.slots.length; s++)
      if (has(chassis.moduleAt(s))) s,
  ];

  Widget _analogInput(int slot, int ch) => AnalogInputTile(slot: slot, channel: ch);

  Widget _analogOutput(int slot, int ch) => AnalogOutputTile(slot: slot, channel: ch);

  Widget _outputTile(int slot, int bit, Program program, RuntimeState runtime) {
    final element = ioElement(BitFile.output, slot, null)!;
    final address = BitAddress(BitFile.output, element, bit);
    final on = slot == program.ioMapping.digitalOutputSlot
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

/// Section title with an optional slot selector on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.style,
    this.picker,
    this.topGap = 0,
  });

  final String title;
  final TextStyle? style;
  final Widget? picker;
  final double topGap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topGap),
    child: Row(
      children: [
        Expanded(child: Text(title, style: style)),
        ?picker,
      ],
    ),
  );
}

/// Drop-down listing the chassis [slots] a function can be mapped to.
class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.pickerKey,
    required this.value,
    required this.slots,
    required this.onChanged,
  });

  final Key pickerKey;
  final int value;
  final List<int> slots;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<int>(
    key: pickerKey,
    value: slots.contains(value) ? value : null,
    style: Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Colors.black),
    items: [
      for (final s in slots) DropdownMenuItem(value: s, child: Text('Slot $s')),
    ],
    onChanged: (s) => onChanged(s ?? value),
  );
}

class _InputTile extends ConsumerWidget {
  const _InputTile({
    required this.slot,
    required this.bit,
    required this.symbol,
    required this.kind,
    required this.on,
    required this.forced,
  });

  final int slot;
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
      address: 'I:$slot/$bit',
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

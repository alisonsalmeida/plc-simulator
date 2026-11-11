import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/runtime_state.model.dart';
import '../../../theme/app_theme.dart';

/// RSLogix 500 "I/O Configuration": the rack with its slots, and the module catalog.
class ChassisConfigView extends ConsumerStatefulWidget {
  const ChassisConfigView({super.key});

  @override
  ConsumerState<ChassisConfigView> createState() => _ChassisConfigViewState();
}

class _ChassisConfigViewState extends ConsumerState<ChassisConfigView> {
  int _slot = 0;
  ModuleDefinition? _module;

  static const _groups = <(String, List<ModuleDefinition>)>[
    ('Processadores', [ModuleCatalog.emu1400, ModuleCatalog.slc503]),
    (
      'Entrada Digital',
      [ModuleCatalog.ib16, ModuleCatalog.ib8, ModuleCatalog.ia16],
    ),
    (
      'Saída Digital',
      [ModuleCatalog.ob16, ModuleCatalog.ow16, ModuleCatalog.ob8],
    ),
    (
      'Analógicas',
      [
        ModuleCatalog.ni4,
        ModuleCatalog.ni8,
        ModuleCatalog.no2,
        ModuleCatalog.no4v,
      ],
    ),
    ('Mistas', [ModuleCatalog.io12, ModuleCatalog.nio4v]),
  ];

  void _install(int slot, ModuleDefinition module) {
    if ((slot == 0) != (module.category == ModuleCategory.cpu)) return;
    ref.read(programProvider.notifier).setChassisSlot(slot, module);
  }

  @override
  Widget build(BuildContext context) {
    final chassis = ref.watch(programProvider.select((s) => s.program.chassis));
    final slot = _slot.clamp(0, chassis.slots.length - 1);
    final slotModule = chassis.moduleAt(slot);
    final module = _module;
    final canInstall =
        module != null &&
        (slot == 0) == (module.category == ModuleCategory.cpu);
    final canRemove = slot > 0 && slotModule.category != ModuleCategory.empty;
    return Container(
      color: const Color(0xFFECEFF1),
      child: Column(
        children: [
          _toolbar(chassis),
          const Divider(height: 1),
          _Rack(
            chassis: chassis,
            selected: slot,
            onSelect: (s) => setState(() => _slot = s),
          ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 280, child: _catalog(slot)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: _details(
                    chassis,
                    slot,
                    slotModule,
                    module,
                    canInstall,
                    canRemove,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(ChassisConfig chassis) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Row(
      children: [
        const Text('Chassi:'),
        const SizedBox(width: 8),
        DropdownButton<ChassisType>(
          key: const ValueKey('chassis-type'),
          value: chassis.type,
          items: [
            for (final t in ChassisType.values)
              DropdownMenuItem(value: t, child: Text(t.label)),
          ],
          onChanged: (t) {
            if (t != null) {
              ref
                  .read(programProvider.notifier)
                  .setChassis(chassis.changeType(t));
            }
          },
        ),
        const Spacer(),
        OutlinedButton(
          key: const ValueKey('chassis-restore'),
          onPressed: () => ref
              .read(programProvider.notifier)
              .setChassis(ChassisConfig.defaultConfig()),
          child: const Text('Restaurar Padrão'),
        ),
      ],
    ),
  );

  Widget _catalog(int slot) => ListView(
    children: [
      for (final (title, modules) in _groups) ...[
        Container(
          color: Colors.black12,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        for (final m in modules)
          GestureDetector(
            onDoubleTap: () => _install(_slot, m),
            child: ListTile(
              key: ValueKey('chassis-module-${m.catalogNumber}'),
              dense: true,
              selected: _module == m,
              title: Text(m.catalogNumber),
              subtitle: Text(m.name),
              leading: Container(
                width: 6,
                height: 28,
                color: _categoryColor(m.category),
              ),
              onTap: () => setState(() => _module = m),
            ),
          ),
      ],
    ],
  );

  Widget _details(
    ChassisConfig chassis,
    int slot,
    ModuleDefinition slotModule,
    ModuleDefinition? module,
    bool canInstall,
    bool canRemove,
  ) {
    final style = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Text('Slot $slot', style: style.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${slotModule.catalogNumber} - ${slotModule.name}',
          key: const ValueKey('chassis-slot-detail'),
        ),
        Text(slotModule.description),
        if (slotModule.category != ModuleCategory.empty)
          Text('Endereços: ${_summary(slotModule, slot)}'),
        const Divider(height: 24),
        Text('Módulo selecionado no catálogo', style: style.titleSmall),
        const SizedBox(height: 4),
        if (module == null)
          const Text(
            'Selecione um módulo na lista (duplo clique instala no slot).',
          )
        else ...[
          Text('${module.catalogNumber} - ${module.name}'),
          Text(module.description),
          Text('Endereços: ${_summary(module, slot)}'),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              key: const ValueKey('chassis-install'),
              onPressed: canInstall ? () => _install(slot, module!) : null,
              child: Text('Instalar no Slot [$slot]'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const ValueKey('chassis-remove'),
              onPressed: canRemove
                  ? () => ref
                        .read(programProvider.notifier)
                        .clearChassisSlot(slot)
                  : null,
              child: Text('Remover do Slot [$slot]'),
            ),
          ],
        ),
      ],
    );
  }

  String _summary(ModuleDefinition m, int slot) {
    final s = m.addressSummary(slot);
    return s.isEmpty ? 'sem E/S' : s;
  }
}

Color _categoryColor(ModuleCategory c) => switch (c) {
  ModuleCategory.cpu => const Color(0xFF455A64),
  ModuleCategory.digitalInput => const Color(0xFF1E88E5),
  ModuleCategory.digitalOutput => const Color(0xFFE65100),
  ModuleCategory.analogInput ||
  ModuleCategory.analogOutput => const Color(0xFF2E7D32),
  ModuleCategory.combination => const Color(0xFF00ACC1),
  ModuleCategory.empty => const Color(0xFF263238),
};

/// The dark metallic enclosure: power supply plus one card per slot.
class _Rack extends StatelessWidget {
  const _Rack({
    required this.chassis,
    required this.selected,
    required this.onSelect,
  });

  final ChassisConfig chassis;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('chassis-rack'),
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF546E7A), Color(0xFF263238)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Visão de Montagem do CLP',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _PowerSupply(),
              for (var s = 0; s < chassis.slots.length; s++)
                _SlotCard(
                  slot: s,
                  module: chassis.moduleAt(s),
                  selected: s == selected,
                  onTap: () => onSelect(s),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Led extends StatelessWidget {
  const _Led({required this.on, this.color = AppColors.energized, this.label});

  final bool on;
  final Color color;
  final String? label;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? color : Colors.black54,
          boxShadow: on ? [BoxShadow(color: color, blurRadius: 4)] : null,
        ),
      ),
      if (label != null)
        Text(
          label!,
          style: const TextStyle(color: Colors.white70, fontSize: 8),
        ),
    ],
  );
}

class _PowerSupply extends StatelessWidget {
  const _PowerSupply();

  @override
  Widget build(BuildContext context) => Container(
    width: 80,
    height: 210,
    margin: const EdgeInsets.only(right: 4),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: const Color(0xFF37474F),
      border: Border.all(color: Colors.black87),
    ),
    child: const Column(
      children: [
        Text(
          'FONTE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text('1746-P2', style: TextStyle(color: Colors.white70, fontSize: 10)),
        Spacer(),
        _Led(on: true, label: 'POWER'),
      ],
    ),
  );
}

class _SlotCard extends ConsumerWidget {
  const _SlotCard({
    required this.slot,
    required this.module,
    required this.selected,
    required this.onTap,
  });

  final int slot;
  final ModuleDefinition module;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeProvider);
    final mapping = ref.watch(
      programProvider.select((s) => s.program.ioMapping),
    );
    final empty = module.category == ModuleCategory.empty;
    final running = runtime.mode != RuntimeMode.stop;
    int word(BitFile f) {
      final element = ioElement(f, slot, null);
      if (element == null) return 0;
      if (slot ==
          (f == BitFile.input
              ? mapping.digitalInputSlot
              : mapping.digitalOutputSlot)) {
        return f == BitFile.input ? runtime.inputs : runtime.outputs;
      }
      if (f == BitFile.output && !running) return 0;
      return runtime.data[f]?[element] ?? 0;
    }

    final inputs = word(BitFile.input);
    final outputs = word(BitFile.output);
    Widget bits(int count, int value, Color color) => Wrap(
      children: [
        for (var b = 0; b < count; b++)
          SizedBox(
            width: 12,
            child: _Led(on: (value >> b) & 1 == 1, color: color),
          ),
      ],
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        key: ValueKey('chassis-slot-$slot'),
        width: 104,
        height: 210,
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: empty ? const Color(0xFF37474F) : const Color(0xFFCFD8DC),
          border: Border.all(
            color: selected ? Colors.amber : Colors.black87,
            width: selected ? 3 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 8, color: _categoryColor(module.category)),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Slot $slot',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: empty ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    empty ? 'Vazio' : module.catalogNumber,
                    style: TextStyle(
                      fontSize: 11,
                      color: empty ? Colors.white54 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (slot == 0)
                    Wrap(
                      spacing: 2,
                      children: [
                        _Led(on: runtime.mode == RuntimeMode.run, label: 'RUN'),
                        const _Led(on: false, color: Colors.red, label: 'FLT'),
                        const _Led(on: false, color: Colors.red, label: 'BATT'),
                        _Led(
                          on: runtime.hasForces,
                          color: Colors.amber,
                          label: 'FORCE',
                        ),
                      ],
                    ),
                  if (module.hasDigitalInputs)
                    bits(module.digitalInputBits, inputs, AppColors.energized),
                  if (module.hasDigitalOutputs)
                    bits(module.digitalOutputBits, outputs, AppColors.lampOn),
                  if (module.hasAnalogInputs)
                    Text(
                      '${module.analogInputChannels} AI',
                      style: const TextStyle(fontSize: 10),
                    ),
                  if (module.hasAnalogOutputs)
                    Text(
                      '${module.analogOutputChannels} AO',
                      style: const TextStyle(fontSize: 10),
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

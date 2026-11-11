import 'address.dart';

/// SLC 500 fixed-size chassis (1746-A4 .. A13).
enum ChassisType {
  a4(4, '1746-A4 (4 Slots)'),
  a7(7, '1746-A7 (7 Slots)'),
  a10(10, '1746-A10 (10 Slots)'),
  a13(13, '1746-A13 (13 Slots)');

  const ChassisType(this.slotCount, this.label);

  final int slotCount;
  final String label;
}

enum ModuleCategory { cpu, digitalInput, digitalOutput, analogInput, analogOutput, combination, empty }

/// One entry of the module catalog: what a card in a slot provides.
class ModuleDefinition {
  const ModuleDefinition({
    required this.catalogNumber,
    required this.name,
    required this.category,
    required this.description,
    this.digitalInputBits = 0,
    this.digitalOutputBits = 0,
    this.analogInputChannels = 0,
    this.analogOutputChannels = 0,
  });

  final String catalogNumber;
  final String name;
  final ModuleCategory category;
  final String description;
  final int digitalInputBits;
  final int digitalOutputBits;
  final int analogInputChannels;
  final int analogOutputChannels;

  bool get hasDigitalInputs => digitalInputBits > 0;
  bool get hasDigitalOutputs => digitalOutputBits > 0;
  bool get hasAnalogInputs => analogInputChannels > 0;
  bool get hasAnalogOutputs => analogOutputChannels > 0;

  @override
  bool operator ==(Object other) =>
      other is ModuleDefinition &&
      other.runtimeType == runtimeType &&
      other.catalogNumber == catalogNumber;

  @override
  int get hashCode => Object.hash(runtimeType, catalogNumber);

  /// Address ranges of this module in [slot], e.g. `I:1/0 .. I:1/15` or `I:1.0 .. I:1.3`.
  String addressSummary(int slot) {
    String range(String first, String last, int count) => count == 1 ? first : '$first .. $last';
    return [
      if (hasDigitalInputs) range('I:$slot/0', 'I:$slot/${digitalInputBits - 1}', digitalInputBits),
      if (hasDigitalOutputs) range('O:$slot/0', 'O:$slot/${digitalOutputBits - 1}', digitalOutputBits),
      if (hasAnalogInputs) range('I:$slot.0', 'I:$slot.${analogInputChannels - 1}', analogInputChannels),
      if (hasAnalogOutputs) range('O:$slot.0', 'O:$slot.${analogOutputChannels - 1}', analogOutputChannels),
    ].join(', ');
  }
}

/// The modules the student can mount.
abstract final class ModuleCatalog {
  static const emu1400 = ModuleDefinition(
    catalogNumber: 'EMU-1400',
    name: 'MicroLogix 1400 Emulado',
    category: ModuleCategory.cpu,
    digitalInputBits: 16,
    digitalOutputBits: 16,
    description: 'Controlador integrado com 16E/16S digitais (I:0 / O:0)',
  );
  static const slc503 = ModuleDefinition(
    catalogNumber: '1747-L532',
    name: 'SLC 5/03 Modular CPU',
    category: ModuleCategory.cpu,
    description: 'Processador modular 16K (sem E/S onboard)',
  );
  static const ib16 = ModuleDefinition(
    catalogNumber: '1746-IB16',
    name: '16-Point 24VDC Sink/Source',
    category: ModuleCategory.digitalInput,
    digitalInputBits: 16,
    description: '16 entradas digitais 24VCC (I:s/0..15)',
  );
  static const ib8 = ModuleDefinition(
    catalogNumber: '1746-IB8',
    name: '8-Point 24VDC Input',
    category: ModuleCategory.digitalInput,
    digitalInputBits: 8,
    description: '8 entradas digitais 24VCC (I:s/0..7)',
  );
  static const ia16 = ModuleDefinition(
    catalogNumber: '1746-IA16',
    name: '16-Point 120VAC Input',
    category: ModuleCategory.digitalInput,
    digitalInputBits: 16,
    description: '16 entradas digitais 120VCA (I:s/0..15)',
  );
  static const ob16 = ModuleDefinition(
    catalogNumber: '1746-OB16',
    name: '16-Point 24VDC Transistor',
    category: ModuleCategory.digitalOutput,
    digitalOutputBits: 16,
    description: '16 saídas digitais 24VCC a transistor (O:s/0..15)',
  );
  static const ow16 = ModuleDefinition(
    catalogNumber: '1746-OW16',
    name: '16-Point Relay Output',
    category: ModuleCategory.digitalOutput,
    digitalOutputBits: 16,
    description: '16 saídas a relé livres de potencial (O:s/0..15)',
  );
  static const ob8 = ModuleDefinition(
    catalogNumber: '1746-OB8',
    name: '8-Point 24VDC Output',
    category: ModuleCategory.digitalOutput,
    digitalOutputBits: 8,
    description: '8 saídas digitais 24VCC (O:s/0..7)',
  );
  static const ni4 = ModuleDefinition(
    catalogNumber: '1746-NI4',
    name: '4-Channel Analog Input',
    category: ModuleCategory.analogInput,
    analogInputChannels: 4,
    description: '4 canais analógicos configuráveis (I:s.0..3)',
  );
  static const ni8 = ModuleDefinition(
    catalogNumber: '1746-NI8',
    name: '8-Channel Analog Input',
    category: ModuleCategory.analogInput,
    analogInputChannels: 8,
    description: '8 canais analógicos configuráveis (I:s.0..7)',
  );
  static const no2 = ModuleDefinition(
    catalogNumber: '1746-NO2',
    name: '2-Channel Analog Output',
    category: ModuleCategory.analogOutput,
    analogOutputChannels: 2,
    description: '2 canais analógicos de saída (O:s.0..1)',
  );
  static const no4v = ModuleDefinition(
    catalogNumber: '1746-NO4V',
    name: '4-Channel Voltage Output',
    category: ModuleCategory.analogOutput,
    analogOutputChannels: 4,
    description: '4 canais analógicos de tensão 0-10V (O:s.0..3)',
  );
  static const io12 = ModuleDefinition(
    catalogNumber: '1746-IO12',
    name: '6-In / 6-Out Digital Combo',
    category: ModuleCategory.combination,
    digitalInputBits: 6,
    digitalOutputBits: 6,
    description: '6 entradas digitais e 6 saídas digitais',
  );
  static const nio4v = ModuleDefinition(
    catalogNumber: '1746-NIO4V',
    name: '2-In / 2-Out Analog Combo',
    category: ModuleCategory.combination,
    analogInputChannels: 2,
    analogOutputChannels: 2,
    description: '2 entradas e 2 saídas analógicas',
  );
  static const empty = ModuleDefinition(
    catalogNumber: 'EMPTY',
    name: 'Slot Vazio',
    category: ModuleCategory.empty,
    description: 'Nenhum módulo instalado',
  );

  /// Every mountable module (the empty slot is not one).
  static const all = [
    emu1400, slc503, ib16, ib8, ia16, ob16, ow16, ob8, ni4, ni8, no2, no4v, io12, nio4v, //
  ];

  /// The module with [catalog] as catalog number (the empty slot included); null when unknown.
  static ModuleDefinition? find(String catalog) {
    for (final m in [...all, empty]) {
      if (m.catalogNumber == catalog) return m;
    }
    return null;
  }
}

/// The rack: its size and the module in each slot. Slot 0 always holds the CPU.
class ChassisConfig {
  const ChassisConfig({required this.type, required this.slots});

  /// The default rack: see [ChassisConfig.defaultConfig].
  static const standard = ChassisConfig(
    type: ChassisType.a10,
    slots: [
      ModuleCatalog.emu1400,
      ModuleCatalog.ni4,
      ModuleCatalog.no2,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
      ModuleCatalog.empty,
    ],
  );

  /// 10-slot chassis: EMU-1400 in slot 0, 1746-NI4 in slot 1, 1746-NO2 in slot 2.
  factory ChassisConfig.defaultConfig() => standard;

  factory ChassisConfig.fromJson(Map<String, Object?> json) {
    final typeName = json['type'];
    final type = ChassisType.values.where((t) => t.name == typeName).firstOrNull ??
        (throw FormatException('Unknown chassis type "$typeName"'));
    final raw = json['slots'];
    if (raw is! List || raw.length != type.slotCount) {
      throw FormatException('chassis.slots must list ${type.slotCount} modules');
    }
    final slots = [
      for (final c in raw) ModuleCatalog.find('$c') ?? (throw FormatException('Unknown module "$c"')),
    ];
    if (slots.first.category != ModuleCategory.cpu) {
      throw const FormatException('chassis.slots[0] must be a CPU');
    }
    return ChassisConfig(type: type, slots: List.unmodifiable(slots));
  }

  final ChassisType type;
  final List<ModuleDefinition> slots;

  ChassisConfig copyWith({ChassisType? type, List<ModuleDefinition>? slots}) =>
      ChassisConfig(type: type ?? this.type, slots: List.unmodifiable(slots ?? this.slots));

  /// Mounts [module] in [slotIndex]: slot 0 takes only a CPU and the other slots never do.
  ChassisConfig setSlot(int slotIndex, ModuleDefinition module) {
    RangeError.checkValidIndex(slotIndex, slots, 'slotIndex');
    if ((slotIndex == 0) != (module.category == ModuleCategory.cpu)) {
      throw ArgumentError('${module.catalogNumber} cannot be mounted in slot $slotIndex');
    }
    return copyWith(slots: [...slots]..[slotIndex] = module);
  }

  /// Empties [slotIndex]; the CPU slot cannot be emptied.
  ChassisConfig clearSlot(int slotIndex) => setSlot(slotIndex, ModuleCatalog.empty);

  /// Resizes the rack; extra slots are dropped, new ones are empty.
  ChassisConfig changeType(ChassisType newType) => ChassisConfig(
        type: newType,
        slots: List.unmodifiable([
          for (var i = 0; i < newType.slotCount; i++) i < slots.length ? slots[i] : ModuleCatalog.empty,
        ]),
      );

  ModuleDefinition moduleAt(int slotIndex) => slots[slotIndex];

  /// Null when [a] exists in this chassis, else the reason (pt-BR). Only `I:` / `O:` addresses
  /// are checked. A bit of the word shared by the digital word and analog channel 0 is valid
  /// if either reading is.
  String? validateBitAddress(BitAddress a) {
    if (!_isIo(a.file)) return null;
    return _validateEither(a.file, a.word, a.bit, '$a');
  }

  /// Null when the word [a] exists in this chassis, else the reason (pt-BR).
  String? validateWordAddress(WordAddress a) {
    if (!_isIo(a.file)) return null;
    return _validateEither(a.file, a.element, null, '$a');
  }

  /// Checks an I/O address by the form it was typed in: [channel] null is the digital form
  /// (`I:s/bit`, `I:s`), else the analog form (`I:s.channel`). [bit] is checked when given;
  /// [label] is the address as shown in the messages.
  String? validateIo(BitFile file, int slot, int? channel, int? bit, String label) {
    if (!_isIo(file)) return null;
    if (slot >= slots.length) return 'Slot $slot fora do chassi configurado (${type.label}).';
    final m = slots[slot];
    if (m.category == ModuleCategory.empty) return 'Slot $slot está vazio; endereço $label não configurado.';
    final input = file == BitFile.input;
    final digitalBits = input ? m.digitalInputBits : m.digitalOutputBits;
    final channels = input ? m.analogInputChannels : m.analogOutputChannels;
    if (channel != null) {
      if (channels == 0) {
        return 'Slot $slot não possui ${input ? 'entradas' : 'saídas'} analógicas (${m.catalogNumber}).';
      }
      if (channel >= channels) {
        return 'Canal .$channel fora da faixa do módulo ${m.catalogNumber} (0..${channels - 1}).';
      }
      return null;
    }
    if (digitalBits == 0) {
      if (channels > 0) {
        return 'Slot $slot possui módulo analógico (${m.catalogNumber}); endereço $label não existe '
            '(use ${input ? 'I' : 'O'}:$slot.canal).';
      }
      final opposite = input ? m.hasDigitalOutputs || m.hasAnalogOutputs : m.hasDigitalInputs || m.hasAnalogInputs;
      if (!opposite) return 'Slot $slot (${m.catalogNumber}) não possui E/S; endereço $label não existe.';
      return 'Slot $slot possui módulo de ${input ? 'saída' : 'entrada'} (${m.catalogNumber}); '
          'endereço $label não existe.';
    }
    if (bit != null && bit >= digitalBits) {
      return 'Bit /$bit fora da faixa do módulo ${m.catalogNumber} (0..${digitalBits - 1}).';
    }
    return null;
  }

  /// Null when [text] is a bit, word or element address that exists in this chassis; else the
  /// reason (pt-BR).
  String? validateAddressString(String text) {
    final t = text.trim();
    final parsers = <Object Function(ChassisConfig?)>[
      (c) => BitAddress.parse(t, chassis: c),
      (c) => WordAddress.parse(t, chassis: c),
      (c) => ElementAddress.parse(t),
    ];
    for (final parse in parsers) {
      try {
        parse(null);
      } on FormatException {
        continue;
      }
      try {
        parse(this);
        return null;
      } on FormatException catch (e) {
        return e.message;
      }
    }
    return 'Endereço inválido: $t';
  }

  Map<String, Object?> toJson() => {
        'type': type.name,
        'slots': [for (final m in slots) m.catalogNumber],
      };

  static bool _isIo(BitFile f) => f == BitFile.input || f == BitFile.output;

  /// [element] is a stored data table word: the digital and the analog reading of the first
  /// word of a slot cannot be told apart, so either one passes.
  String? _validateEither(BitFile file, int element, int? bit, String label) {
    final slot = ioSlotOf(file, element);
    final channel = ioChannelOf(file, element);
    if (channel != null || element == 0) return validateIo(file, slot, channel, bit, label);
    final digital = validateIo(file, slot, null, bit, label);
    if (digital == null) return null;
    return validateIo(file, slot, 0, bit, label) == null ? null : digital;
  }
}

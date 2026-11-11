import 'chassis.dart';

/// Data files (SLC 500 style). Plain files hold one 16-bit word per address word; the
/// structured files (timers, counters) hold [stride] words per element: status bits, PRE, ACC.
enum BitFile {
  // O: word 0 is O:0 (slot 0, 16 digital outputs); words 1..2 are the analog output module
  // in slot 2 (O:2.0, O:2.1). I: word 0 is I:0; words 1..4 are the analog input module in
  // slot 1 (I:1.0 .. I:1.3). From word 5 on, every slot s >= 1 owns 8 words:
  // word 5 + (s - 1) * 8 + w is `I:s.w` / `O:s.w` (w = 0 is also the digital word `I:s/bit`).
  output('O', 128),
  input('I', 128),
  status('S', 6),
  bit('B3', 16),
  timer('T4', 16, stride: 3, bitNames: {'EN': 15, 'TT': 14, 'DN': 13}),
  counter('C5', 16, stride: 3, bitNames: {'CU': 15, 'CD': 14, 'DN': 13, 'OV': 12, 'UN': 11}),
  integer('N7', 32),
  // R6: control elements of the shift register and FIFO/LIFO instructions: status bits, LEN, POS.
  control('R6', 16, stride: 3, bitNames: {'EN': 15, 'EU': 14, 'DN': 13, 'EM': 12, 'ER': 11, 'UL': 10, 'IN': 9, 'FD': 8}),
  // F8: 32-bit IEEE-754 floats, two words per element (low word first).
  float('F8', 16, stride: 2);

  const BitFile(this.prefix, this.elements, {this.stride = 1, this.bitNames = const {}});

  final String prefix;

  /// Number of addressable words (plain files) or elements (structured files).
  final int elements;

  /// Words stored per element: the status word is first, then PRE and ACC.
  final int stride;

  /// Mnemonic of each named status bit (structured files only).
  final Map<String, int> bitNames;

  /// Total words in the data table.
  int get words => elements * stride;

  /// Index in the file's word array of the first word of [element].
  int wordIndex(int element) => element * stride;

  /// Address text of [element] after the prefix: `0`, `1.2` (analog I/O slot syntax) or `5`.
  String elementLabel(int element) => switch (this) {
        BitFile.input || BitFile.output when element == 0 => '0',
        BitFile.input when element <= 4 => '$analogInputSlot.${element - 1}',
        BitFile.output when element <= 2 => '$analogOutputSlot.${element - 1}',
        BitFile.input || BitFile.output when element >= 5 => _ioLabel(element),
        _ => '$element',
      };

  static String _ioLabel(int element) {
    final slot = 1 + (element - 5) ~/ 8;
    final sub = (element - 5) % 8;
    return sub == 0 ? '$slot' : '$slot.$sub';
  }
}

/// Chassis slot of the analog input module (`I:1.0` .. `I:1.3`).
const analogInputSlot = 1;

/// Chassis slot of the analog output module (`O:2.0`, `O:2.1`).
const analogOutputSlot = 2;

/// Number of analog input and output channels.
const analogInputChannels = 4;
const analogOutputChannels = 2;

/// Data table word of the I/O [file] for [slot] and analog [channel] (null = the digital
/// word `I:s/bit`); null when out of range. `I:1.0..3` and `O:2.0..1` keep their legacy words
/// 1..4 and 1..2; every other slot s >= 1 owns the 8 words from `5 + (s - 1) * 8`.
int? ioElement(BitFile file, int slot, int? channel) {
  if (slot < 0 || slot > 15) return null;
  if (slot == 0) return channel == null ? 0 : null;
  final w = channel ?? 0;
  if (w > 7) return null;
  if (channel != null) {
    if (file == BitFile.input && slot == analogInputSlot && w < analogInputChannels) return 1 + w;
    if (file == BitFile.output && slot == analogOutputSlot && w < analogOutputChannels) return 1 + w;
  }
  return 5 + (slot - 1) * 8 + w;
}

/// Slot of the I/O data table word [element] of [file].
int ioSlotOf(BitFile file, int element) => element == 0
    ? 0
    : (element <= 4 && file == BitFile.input
        ? analogInputSlot
        : (element <= 2 && file == BitFile.output ? analogOutputSlot : 1 + (element - 5) ~/ 8));

/// Analog channel of the I/O word [element]; null for the digital word (`I:s/bit`). The word
/// `5 + (s - 1) * 8` is both the digital word and analog channel 0 of slot s: null there.
int? ioChannelOf(BitFile file, int element) {
  if (element == 0) return null;
  if (element <= 4 && file == BitFile.input) return element - 1;
  if (element <= 2 && file == BitFile.output) return element - 1;
  final sub = (element - 5) % 8;
  return sub == 0 ? null : sub;
}

int? _ioElement(BitFile file, String slot, String? word) =>
    ioElement(file, int.parse(slot), word == null ? null : int.parse(word));

/// A single bit in a data file, e.g. `I:0/0`, `O:0/15`, `S:1/15`, `B3:0/3`, `B3/17`,
/// `N7:0/3`, `T4:0/DN`, `C5:3/CU`. In structured files [word] is the element number.
class BitAddress {
  const BitAddress(this.file, this.word, this.bit);

  /// Parses an address; throws [FormatException] when invalid or out of range.
  /// Timer and counter bits accept a mnemonic (`T4:0/DN`) or a bit number (`T4:0/13`).
  ///
  /// With a [chassis], I/O addresses are also checked against the mounted modules.
  factory BitAddress.parse(String text, {ChassisConfig? chassis}) {
    final s = text.trim().toUpperCase();
    final io = RegExp(r'^([IOS]|N7):(\d+)/(\d+)$').firstMatch(s);
    final analog = RegExp(r'^([IO]):(\d+)\.(\d+)/(\d+)$').firstMatch(s);
    final b3 = RegExp(r'^B3:(\d+)/(\d+)$').firstMatch(s);
    final b3Flat = RegExp(r'^B3/(\d+)$').firstMatch(s);
    final structured = RegExp(r'^(T4|C5|R6):(\d+)/([A-Z0-9]+)$').firstMatch(s);
    final BitFile file;
    final int word;
    final int bit;
    if (analog != null) {
      file = BitFile.values.firstWhere((f) => f.prefix == analog[1]);
      word = _ioElement(file, analog[2]!, analog[3]) ?? (throw FormatException('Bit address out of range', text));
      bit = int.parse(analog[4]!);
    } else if (io != null) {
      file = BitFile.values.firstWhere((f) => f.prefix == io[1]);
      word = file == BitFile.input || file == BitFile.output
          ? _ioElement(file, io[2]!, null) ?? (throw FormatException('Bit address out of range', text))
          : int.parse(io[2]!);
      bit = int.parse(io[3]!);
    } else if (b3 != null) {
      file = BitFile.bit;
      word = int.parse(b3[1]!);
      bit = int.parse(b3[2]!);
    } else if (b3Flat != null) {
      file = BitFile.bit;
      final n = int.parse(b3Flat[1]!);
      word = n ~/ 16;
      bit = n % 16;
    } else if (structured != null) {
      file = BitFile.values.firstWhere((f) => f.prefix == structured[1]);
      word = int.parse(structured[2]!);
      final parsed = file.bitNames[structured[3]] ?? int.tryParse(structured[3]!);
      if (parsed == null) throw FormatException('Unknown bit', text);
      bit = parsed;
    } else {
      throw FormatException('Invalid bit address', text);
    }
    if (word >= file.elements || bit > 15) {
      throw FormatException('Bit address out of range', text);
    }
    final result = BitAddress(file, word, bit);
    final error = chassis?.validateIo(file, ioSlotOf(file, word),
        analog == null ? null : int.parse(analog[3]!), bit, s);
    if (error != null) throw FormatException(error, text);
    return result;
  }

  final BitFile file;
  final int word;
  final int bit;

  /// Chassis slot of an `I:` / `O:` address.
  int get slot => ioSlotOf(file, word);

  /// The bit part as printed: the mnemonic for named timer/counter bits, else the number.
  String get bitLabel {
    for (final MapEntry(:key, :value) in file.bitNames.entries) {
      if (value == bit) return key;
    }
    return '$bit';
  }

  @override
  bool operator ==(Object other) =>
      other is BitAddress && other.file == file && other.word == word && other.bit == bit;

  @override
  int get hashCode => Object.hash(file, word, bit);

  @override
  String toString() => '${file.prefix}:${file.elementLabel(word)}/$bitLabel';
}

/// A timer, counter or control element, e.g. `T4:0`, `C5:3`, `R6:0`.
class ElementAddress {
  const ElementAddress(this.file, this.index);

  /// Parses `T4:n` / `C5:n` / `R6:n` (restricted to [only] when given); throws [FormatException]
  /// when invalid or out of range.
  factory ElementAddress.parse(String text, {BitFile? only}) {
    final m = RegExp(r'^(T4|C5|R6):(\d+)$').firstMatch(text.trim().toUpperCase());
    if (m == null) throw FormatException('Invalid element address', text);
    final file = BitFile.values.firstWhere((f) => f.prefix == m[1]);
    final index = int.parse(m[2]!);
    if ((only != null && file != only) || index >= file.elements) {
      throw FormatException('Element address out of range', text);
    }
    return ElementAddress(file, index);
  }

  final BitFile file;
  final int index;

  /// Index of the status word in the file's word array; PRE and ACC follow it.
  int get statusIndex => file.wordIndex(index);
  int get presetIndex => statusIndex + 1;
  int get accumIndex => statusIndex + 2;

  /// Control elements (`R6:n`) store the length and the position in the PRE / ACC words.
  int get lenIndex => statusIndex + 1;
  int get posIndex => statusIndex + 2;

  /// The status bit [bit] of this element.
  BitAddress bitAt(int bit) => BitAddress(file, index, bit);

  @override
  bool operator ==(Object other) =>
      other is ElementAddress && other.file == file && other.index == index;

  @override
  int get hashCode => Object.hash(file, index);

  @override
  String toString() => '${file.prefix}:$index';
}

/// Canonical text of a bit, element or word address; throws [FormatException] when none.
String canonicalAddress(String text) {
  try {
    return BitAddress.parse(text).toString();
  } on FormatException {
    try {
      return ElementAddress.parse(text).toString();
    } on FormatException {
      return WordAddress.parse(text).toString();
    }
  }
}

/// A source or mask of a word instruction: a [WordAddress], a [Constant] or a [FloatConstant].
sealed class Operand {
  const Operand();

  /// Parses a word address, a float literal (`12.5`) or an integer constant (decimal, −32768..32767). When [mask] is
  /// true a constant may also be hex: `00FFh` or `0x00FF` (up to 4 digits). Throws
  /// [FormatException] when invalid or out of range.
  factory Operand.parse(String text, {bool mask = false}) {
    final s = text.trim().toUpperCase();
    final decimal = RegExp(r'^[+-]?\d+$').hasMatch(s);
    final hex = mask ? RegExp(r'^(?:0X([0-9A-F]{1,4})|([0-9A-F]{1,4})H)$').firstMatch(s) : null;
    if (RegExp(r'^[+-]?\d+\.\d+$').hasMatch(s)) return FloatConstant(double.parse(s));
    if (decimal) {
      final v = int.parse(s);
      if (v < -32768 || v > 32767) throw FormatException('Constant out of range', text);
      return Constant(v);
    }
    if (hex != null) return Constant(toInt16(int.parse(hex[1] ?? hex[2]!, radix: 16)));
    return WordAddress.parse(s);
  }

  /// Canonical text; a constant is printed as hex (`00FFh`) when [hex] is true.
  String format({bool hex = false});

  @override
  String toString() => format();
}

/// An integer constant (signed 16-bit).
final class Constant extends Operand {
  const Constant(this.value);

  final int value;

  @override
  String format({bool hex = false}) => hex
      ? '${(value & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0')}h'
      : '$value';

  @override
  bool operator ==(Object other) => other is Constant && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// A floating-point constant (32-bit REAL), e.g. `12.5`.
final class FloatConstant extends Operand {
  const FloatConstant(this.value);

  final double value;

  @override
  String format({bool hex = false}) => '$value';

  @override
  bool operator ==(Object other) => other is FloatConstant && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Which word of a data file element a [WordAddress] points at.
enum WordField { word, pre, acc }

/// A 16-bit word in a data file (or the first word of a float `F8:n`): `N7:n`, `B3:n`, `O:0`, `I:0`, `S:0`/`S:1`, or the preset
/// / accumulator of a timer or counter: `T4:n.PRE`, `T4:n.ACC`, `C5:n.PRE`, `C5:n.ACC`, or the
/// length / position of a control element: `R6:n.LEN`, `R6:n.POS`.
final class WordAddress extends Operand {
  const WordAddress(this.file, this.element, [this.field = WordField.word]);

  /// Parses a word address; throws [FormatException] when invalid or out of range.
  ///
  /// With a [chassis], I/O addresses are also checked against the mounted modules.
  factory WordAddress.parse(String text, {ChassisConfig? chassis}) {
    final s = (text.trim().startsWith('#') ? text.trim().substring(1) : text.trim()).toUpperCase();
    final plain = RegExp(r'^(S|B3|N7|F8):(\d+)$').firstMatch(s);
    final io = RegExp(r'^(O|I):(\d+)(?:\.(\d+))?$').firstMatch(s);
    final structured = RegExp(r'^(T4|C5):(\d+)\.(ACC|PRE)$').firstMatch(s) ??
        RegExp(r'^(R6):(\d+)\.(LEN|POS|PRE|ACC)$').firstMatch(s);
    final m = plain ?? io ?? structured;
    if (m == null) throw FormatException('Invalid word address', text);
    final file = BitFile.values.firstWhere((f) => f.prefix == m[1]);
    final element = io != null
        ? _ioElement(file, io[2]!, io[3]) ?? (throw FormatException('Word address out of range', text))
        : int.parse(m[2]!);
    if (element >= file.elements) throw FormatException('Word address out of range', text);
    final result = WordAddress(file, element, switch (structured?[3]) {
      'ACC' || 'POS' => WordField.acc,
      'PRE' || 'LEN' => WordField.pre,
      _ => WordField.word,
    });
    // `I:2.0` and `I:2` share a word: the typed form decides how it is checked.
    final error = io == null
        ? null
        : chassis?.validateIo(file, ioSlotOf(file, element), io[3] == null ? null : int.parse(io[3]!), null, s);
    if (error != null) throw FormatException(error, text);
    return result;
  }

  final BitFile file;

  /// Word number (plain files) or element number (T4 / C5).
  final int element;
  final WordField field;

  /// Index of the word in the file's word array.
  int get index => file.wordIndex(element) + field.index;

  /// Chassis slot of an `I:` / `O:` word.
  int get slot => ioSlotOf(file, element);

  /// Analog channel of an `I:` / `O:` word; null for a digital word.
  int? get channel => ioChannelOf(file, element);

  @override
  String format({bool hex = false}) => field == WordField.word
      ? '${file.prefix}:${file.elementLabel(element)}'
      : '${file.prefix}:$element.${file == BitFile.control ? (field == WordField.pre ? 'LEN' : 'POS') : field.name.toUpperCase()}';

  @override
  bool operator ==(Object other) =>
      other is WordAddress && other.file == file && other.element == element && other.field == field;

  @override
  int get hashCode => Object.hash(file, element, field);
}

/// Timer status bits (T4 files).
abstract final class TimerBit {
  static const en = 15;
  static const tt = 14;
  static const dn = 13;
}

/// Counter status bits (C5 files).
abstract final class CounterBit {
  static const cu = 15;
  static const cd = 14;
  static const dn = 13;
  static const ov = 12;
  static const un = 11;
}

/// Control element status bits (R6 files).
abstract final class ControlBit {
  static const en = 15;
  static const eu = 14;
  static const dn = 13;
  static const em = 12;
  static const er = 11;
  static const ul = 10;
  static const fd = 8;
}

/// Interprets the low 16 bits of [value] as a signed integer.
int toInt16(int value) {
  final v = value & 0xFFFF;
  return v >= 0x8000 ? v - 0x10000 : v;
}

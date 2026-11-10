/// Data files (SLC 500 style). Plain files hold one 16-bit word per address word; the
/// structured files (timers, counters) hold [stride] words per element: status bits, PRE, ACC.
enum BitFile {
  output('O', 1),
  input('I', 1),
  status('S', 2),
  bit('B3', 16),
  timer('T4', 16, stride: 3, bitNames: {'EN': 15, 'TT': 14, 'DN': 13}),
  counter('C5', 16, stride: 3, bitNames: {'CU': 15, 'CD': 14, 'DN': 13, 'OV': 12, 'UN': 11}),
  integer('N7', 32);

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
}

/// A single bit in a data file, e.g. `I:0/0`, `O:0/15`, `S:1/15`, `B3:0/3`, `B3/17`,
/// `N7:0/3`, `T4:0/DN`, `C5:3/CU`. In structured files [word] is the element number.
class BitAddress {
  const BitAddress(this.file, this.word, this.bit);

  /// Parses an address; throws [FormatException] when invalid or out of range.
  /// Timer and counter bits accept a mnemonic (`T4:0/DN`) or a bit number (`T4:0/13`).
  factory BitAddress.parse(String text) {
    final s = text.trim().toUpperCase();
    final io = RegExp(r'^([IOS]|N7):(\d+)/(\d+)$').firstMatch(s);
    final b3 = RegExp(r'^B3:(\d+)/(\d+)$').firstMatch(s);
    final b3Flat = RegExp(r'^B3/(\d+)$').firstMatch(s);
    final structured = RegExp(r'^(T4|C5):(\d+)/([A-Z0-9]+)$').firstMatch(s);
    final BitFile file;
    final int word;
    final int bit;
    if (io != null) {
      file = BitFile.values.firstWhere((f) => f.prefix == io[1]);
      word = int.parse(io[2]!);
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
    return BitAddress(file, word, bit);
  }

  final BitFile file;
  final int word;
  final int bit;

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
  String toString() => '${file.prefix}:$word/$bitLabel';
}

/// A timer or counter element, e.g. `T4:0`, `C5:3`.
class ElementAddress {
  const ElementAddress(this.file, this.index);

  /// Parses `T4:n` / `C5:n` (restricted to [only] when given); throws [FormatException]
  /// when invalid or out of range.
  factory ElementAddress.parse(String text, {BitFile? only}) {
    final m = RegExp(r'^(T4|C5):(\d+)$').firstMatch(text.trim().toUpperCase());
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

/// A source or mask of a word instruction: a [WordAddress] or a [Constant].
sealed class Operand {
  const Operand();

  /// Parses a word address or an integer constant (decimal, −32768..32767). When [mask] is
  /// true a constant may also be hex: `00FFh` or `0x00FF` (up to 4 digits). Throws
  /// [FormatException] when invalid or out of range.
  factory Operand.parse(String text, {bool mask = false}) {
    final s = text.trim().toUpperCase();
    final decimal = RegExp(r'^[+-]?\d+$').hasMatch(s);
    final hex = mask ? RegExp(r'^(?:0X([0-9A-F]{1,4})|([0-9A-F]{1,4})H)$').firstMatch(s) : null;
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

/// Which word of a data file element a [WordAddress] points at.
enum WordField { word, pre, acc }

/// A 16-bit word in a data file: `N7:n`, `B3:n`, `O:0`, `I:0`, `S:0`/`S:1`, or the preset
/// / accumulator of a timer or counter: `T4:n.PRE`, `T4:n.ACC`, `C5:n.PRE`, `C5:n.ACC`.
final class WordAddress extends Operand {
  const WordAddress(this.file, this.element, [this.field = WordField.word]);

  /// Parses a word address; throws [FormatException] when invalid or out of range.
  factory WordAddress.parse(String text) {
    final s = text.trim().toUpperCase();
    final plain = RegExp(r'^(O|I|S|B3|N7):(\d+)$').firstMatch(s);
    final structured = RegExp(r'^(T4|C5):(\d+)\.(ACC|PRE)$').firstMatch(s);
    final m = plain ?? structured;
    if (m == null) throw FormatException('Invalid word address', text);
    final file = BitFile.values.firstWhere((f) => f.prefix == m[1]);
    final element = int.parse(m[2]!);
    if (element >= file.elements) throw FormatException('Word address out of range', text);
    return WordAddress(file, element, switch (structured?[3]) {
      'ACC' => WordField.acc,
      'PRE' => WordField.pre,
      _ => WordField.word,
    });
  }

  final BitFile file;

  /// Word number (plain files) or element number (T4 / C5).
  final int element;
  final WordField field;

  /// Index of the word in the file's word array.
  int get index => file.wordIndex(element) + field.index;

  @override
  String format({bool hex = false}) =>
      field == WordField.word ? '${file.prefix}:$element' : '${file.prefix}:$element.${field.name.toUpperCase()}';

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

/// Interprets the low 16 bits of [value] as a signed integer.
int toInt16(int value) {
  final v = value & 0xFFFF;
  return v >= 0x8000 ? v - 0x10000 : v;
}

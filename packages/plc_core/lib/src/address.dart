/// Data files (SLC 500 style). Plain files hold one 16-bit word per address word; the
/// structured files (timers, counters) hold [stride] words per element: status bits, PRE, ACC.
enum BitFile {
  output('O', 1),
  input('I', 1),
  status('S', 2),
  bit('B3', 16),
  timer('T4', 16, stride: 3, bitNames: {'EN': 15, 'TT': 14, 'DN': 13}),
  counter('C5', 16, stride: 3, bitNames: {'CU': 15, 'CD': 14, 'DN': 13, 'OV': 12, 'UN': 11});

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
/// `T4:0/DN`, `C5:3/CU`. In structured files [word] is the element number.
class BitAddress {
  const BitAddress(this.file, this.word, this.bit);

  /// Parses an address; throws [FormatException] when invalid or out of range.
  /// Timer and counter bits accept a mnemonic (`T4:0/DN`) or a bit number (`T4:0/13`).
  factory BitAddress.parse(String text) {
    final s = text.trim().toUpperCase();
    final io = RegExp(r'^([IOS]):(\d+)/(\d+)$').firstMatch(s);
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

/// Canonical text of a bit or element address; throws [FormatException] when neither.
String canonicalAddress(String text) {
  try {
    return BitAddress.parse(text).toString();
  } on FormatException {
    return ElementAddress.parse(text).toString();
  }
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

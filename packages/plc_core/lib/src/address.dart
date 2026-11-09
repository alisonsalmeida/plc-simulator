/// Bit-addressable data files (SLC 500 style) and their sizes in words.
enum BitFile {
  output('O', 1),
  input('I', 1),
  status('S', 2),
  bit('B3', 16);

  const BitFile(this.prefix, this.words);

  final String prefix;
  final int words;
}

/// A single bit in a data file, e.g. `I:0/0`, `O:0/15`, `S:1/15`, `B3:0/3`, `B3/17`.
class BitAddress {
  const BitAddress(this.file, this.word, this.bit);

  /// Parses an address; throws [FormatException] when invalid or out of range.
  factory BitAddress.parse(String text) {
    final s = text.trim().toUpperCase();
    final io = RegExp(r'^([IOS]):(\d+)/(\d+)$').firstMatch(s);
    final b3 = RegExp(r'^B3:(\d+)/(\d+)$').firstMatch(s);
    final b3Flat = RegExp(r'^B3/(\d+)$').firstMatch(s);
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
    } else {
      throw FormatException('Invalid bit address', text);
    }
    if (word >= file.words || bit > 15) {
      throw FormatException('Bit address out of range', text);
    }
    return BitAddress(file, word, bit);
  }

  final BitFile file;
  final int word;
  final int bit;

  @override
  bool operator ==(Object other) =>
      other is BitAddress && other.file == file && other.word == word && other.bit == bit;

  @override
  int get hashCode => Object.hash(file, word, bit);

  @override
  String toString() => '${file.prefix}:$word/$bit';
}

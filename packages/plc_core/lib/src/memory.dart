import 'dart:typed_data';

import 'address.dart';

/// The PLC data table: one 16-bit word array per data file.
class PlcMemory {
  final Map<BitFile, Uint16List> _files = {
    for (final f in BitFile.values) f: Uint16List(f.words),
  };

  /// Raw word [index] of [file] (for structured files: status, PRE, ACC per element).
  int word(BitFile file, int index) => _files[file]![index];

  void setWord(BitFile file, int index, int value) => _files[file]![index] = value;

  bool readBit(BitAddress a) => (_files[a.file]![a.file.wordIndex(a.word)] >> a.bit) & 1 == 1;

  void writeBit(BitAddress a, bool value) {
    final words = _files[a.file]!;
    final i = a.file.wordIndex(a.word);
    final mask = 1 << a.bit;
    words[i] = value ? words[i] | mask : words[i] & ~mask;
  }

  /// Value (signed 16-bit) of the word at [a].
  int readWord(WordAddress a) => toInt16(_files[a.file]![a.index]);

  /// Stores the low 16 bits of [value] in the word at [a].
  void writeWord(WordAddress a, int value) => _files[a.file]![a.index] = value;

  /// IEEE-754 32-bit float stored in the two words of the `F8` element at [a] (low word first).
  double readFloat(WordAddress a) {
    final words = _files[a.file]!;
    return (ByteData(4)
          ..setUint16(0, words[a.index], Endian.little)
          ..setUint16(2, words[a.index + 1], Endian.little))
        .getFloat32(0, Endian.little);
  }

  /// Stores [value] as a 32-bit float in the two words of the `F8` element at [a].
  void writeFloat(WordAddress a, double value) {
    final data = ByteData(4)..setFloat32(0, value, Endian.little);
    final words = _files[a.file]!;
    words[a.index] = data.getUint16(0, Endian.little);
    words[a.index + 1] = data.getUint16(2, Endian.little);
  }

  /// Copies the words of [files] from [other].
  void copyFrom(PlcMemory other, Iterable<BitFile> files) {
    for (final f in files) {
      _files[f]!.setAll(0, other._files[f]!);
    }
  }

  /// Preset and accumulated values of a timer/counter element (signed 16-bit).
  int pre(ElementAddress e) => toInt16(_files[e.file]![e.presetIndex]);
  int acc(ElementAddress e) => toInt16(_files[e.file]![e.accumIndex]);

  /// Length and position of a control element (`R6:n`, signed 16-bit).
  int len(ElementAddress e) => toInt16(_files[e.file]![e.lenIndex]);
  int pos(ElementAddress e) => toInt16(_files[e.file]![e.posIndex]);

  void setLen(ElementAddress e, int val) => _files[e.file]![e.lenIndex] = val;
  void setPos(ElementAddress e, int val) => _files[e.file]![e.posIndex] = val;

  void setPre(ElementAddress e, int value) => _files[e.file]![e.presetIndex] = value;
  void setAcc(ElementAddress e, int value) => _files[e.file]![e.accumIndex] = value;
}

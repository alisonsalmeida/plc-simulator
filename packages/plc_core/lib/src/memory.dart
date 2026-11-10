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

  /// Preset and accumulated values of a timer/counter element (signed 16-bit).
  int pre(ElementAddress e) => toInt16(_files[e.file]![e.presetIndex]);
  int acc(ElementAddress e) => toInt16(_files[e.file]![e.accumIndex]);

  void setPre(ElementAddress e, int value) => _files[e.file]![e.presetIndex] = value;
  void setAcc(ElementAddress e, int value) => _files[e.file]![e.accumIndex] = value;
}

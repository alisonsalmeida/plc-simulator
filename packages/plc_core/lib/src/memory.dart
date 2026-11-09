import 'dart:typed_data';

import 'address.dart';

/// The PLC data table: one 16-bit word array per data file.
class PlcMemory {
  final Map<BitFile, Uint16List> _files = {
    for (final f in BitFile.values) f: Uint16List(f.words),
  };

  int word(BitFile file, int index) => _files[file]![index];

  void setWord(BitFile file, int index, int value) => _files[file]![index] = value;

  bool readBit(BitAddress a) => (_files[a.file]![a.word] >> a.bit) & 1 == 1;

  void writeBit(BitAddress a, bool value) {
    final words = _files[a.file]!;
    final mask = 1 << a.bit;
    words[a.word] = value ? words[a.word] | mask : words[a.word] & ~mask;
  }
}

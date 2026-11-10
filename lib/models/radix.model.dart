import 'package:plc_core/plc_core.dart';

/// Number base used to show and edit the words of an integer file.
enum Radix {
  binary('bin', 'Binary'),
  decimal('dec', 'Decimal'),
  hex('hex', 'Hex');

  const Radix(this.tag, this.label);

  /// Short tag shown in the data file title, e.g. `Data File N7 (dec)`.
  final String tag;
  final String label;

  /// Text of the signed 16-bit [value]: decimal as is, hex in 4 digits, binary in 16.
  String format(int value) => switch (this) {
        Radix.decimal => toInt16(value).toString(),
        Radix.hex => (value & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0'),
        Radix.binary => (value & 0xFFFF).toRadixString(2).padLeft(16, '0'),
      };

  /// Parses [text] in this base into a signed 16-bit value, or null when it is invalid or
  /// does not fit. Hex accepts a `0x` prefix or an `h` suffix.
  int? parse(String text) {
    final s = text.trim();
    switch (this) {
      case Radix.decimal:
        final v = int.tryParse(s);
        return v != null && v >= -32768 && v <= 32767 ? v : null;
      case Radix.hex:
        final m = RegExp(r'^(?:0x([0-9a-f]{1,4})|([0-9a-f]{1,4})h?)$', caseSensitive: false)
            .firstMatch(s);
        return m == null ? null : toInt16(int.parse(m[1] ?? m[2]!, radix: 16));
      case Radix.binary:
        return RegExp(r'^[01]{1,16}$').hasMatch(s) ? toInt16(int.parse(s, radix: 2)) : null;
    }
  }
}

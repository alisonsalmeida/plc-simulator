import 'package:plc_core/plc_core.dart';

import 'radix.model.dart';

/// UI state of the Data Files window.
class DataTableState {
  const DataTableState({
    this.open = false,
    this.file = BitFile.integer,
    this.radix = Radix.decimal,
    this.heightFraction = 0.4,
  });

  final bool open;

  /// The data file being shown.
  final BitFile file;

  /// Base of the integer file's words.
  final Radix radix;

  /// Share of the editor's height taken by the window when open.
  final double heightFraction;

  DataTableState copyWith({bool? open, BitFile? file, Radix? radix, double? heightFraction}) => DataTableState(
        open: open ?? this.open,
        file: file ?? this.file,
        radix: radix ?? this.radix,
        heightFraction: heightFraction ?? this.heightFraction,
      );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../models/data_table_state.model.dart';
import '../models/radix.model.dart';

class DataTableController extends Notifier<DataTableState> {
  @override
  DataTableState build() => const DataTableState();

  void show() => state = state.copyWith(open: true);
  void hide() => state = state.copyWith(open: false);
  void selectFile(BitFile file) => state = state.copyWith(file: file);
  void setRadix(Radix radix) => state = state.copyWith(radix: radix);
  void setHeightFraction(double f) => state = state.copyWith(heightFraction: f.clamp(0.15, 0.85));
}

final dataTableProvider =
    NotifierProvider<DataTableController, DataTableState>(DataTableController.new);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import 'runtime.controller.dart';

/// Edits the data table directly, in STOP and in RUN.
class DataEditController extends Notifier<void> {
  @override
  void build() {}

  void writeWord(WordAddress address, int value) =>
      ref.read(runtimeServiceProvider).writeWord(address, value);

  void writeFloat(WordAddress address, double value) =>
      ref.read(runtimeServiceProvider).writeFloat(address, value);

  void toggleBit(BitAddress address) => ref.read(runtimeServiceProvider).toggleBit(address);

  void setBit(BitAddress address, bool value) =>
      ref.read(runtimeServiceProvider).setBit(address, value);
}

final dataEditProvider = NotifierProvider<DataEditController, void>(DataEditController.new);

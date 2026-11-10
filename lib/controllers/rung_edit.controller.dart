import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import 'program.controller.dart';

/// Edits the program around the rungs: adding/removing rungs, titles, comments, symbols and
/// descriptions.
class RungEditController extends Notifier<void> {
  @override
  void build() {}

  /// Inserts an empty rung at [index] (0..length) and selects it.
  void insertRung(int index) {
    _edit((p) => p.copyWith(rungs: [...p.rungs.take(index), const Rung([]), ...p.rungs.skip(index)]));
    ref.read(programProvider.notifier).selectRung(index);
  }

  /// Adds an empty rung after the selected rung, or at the end when none is selected.
  void addRung() {
    final state = ref.read(programProvider);
    insertRung(state.selectedRung == null ? state.program.rungs.length : state.selectedRung! + 1);
  }

  void deleteRung(int rung) {
    _edit((p) => p.copyWith(rungs: [...p.rungs.take(rung), ...p.rungs.skip(rung + 1)]));
    ref.read(programProvider.notifier).selectRung(null);
  }

  /// Deletes the selected rung, if any.
  void deleteSelectedRung() {
    final selected = ref.read(programProvider).selectedRung;
    if (selected != null) deleteRung(selected);
  }

  void setComment(int rung, String comment) => _setRung(rung, (r) => r.copyWith(comment: comment));

  void setTitle(int rung, String title) => _setRung(rung, (r) => r.copyWith(title: title));

  /// Sets the symbol of [address]; an empty [symbol] removes it.
  void setSymbol(String address, String symbol) => _edit((p) =>
      p.copyWith(symbols: _withEntry(p.symbols, address, symbol)));

  /// Sets the multi-line description of [address]; an empty [description] removes it.
  void setDescription(String address, String description) => _edit((p) =>
      p.copyWith(descriptions: _withEntry(p.descriptions, address, description)));

  Map<String, String> _withEntry(Map<String, String> map, String address, String text) {
    final key = BitAddress.parse(address).toString();
    final result = {...map};
    if (text.trim().isEmpty) {
      result.remove(key);
    } else {
      result[key] = text.trim();
    }
    return result;
  }

  void _setRung(int rung, Rung Function(Rung) change) => _edit((p) {
        final rungs = [...p.rungs];
        rungs[rung] = change(rungs[rung]);
        return p.copyWith(rungs: rungs);
      });

  void _edit(Program Function(Program) change) {
    final controller = ref.read(programProvider.notifier);
    controller.replaceProgram(change(ref.read(programProvider).program));
  }
}

final rungEditProvider = NotifierProvider<RungEditController, void>(RungEditController.new);

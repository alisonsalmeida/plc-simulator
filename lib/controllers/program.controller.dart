import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../core/examples.dart';
import '../models/program_state.model.dart';

/// Holds the examples, the program shown in the editor and the selected rung. Edits go
/// through `ElementEditController` and `RungEditController`, which call [replaceProgram].
class ProgramController extends Notifier<ProgramState> {
  @override
  ProgramState build() => ProgramState(examples: ladderExamples);

  /// Loads a copy of the example at [index] as the current program (no rung selected).
  void select(int index) => state = ProgramState(examples: state.examples, selected: index);

  /// Replaces the program; the selection is dropped if its rung no longer exists.
  void replaceProgram(Program program) {
    final rung = state.selectedRung;
    state = state.copyWith(
      program: program,
      clearSelection: rung != null && rung >= program.rungs.length,
    );
  }

  /// Selects the rung at [index]; null clears the selection.
  void selectRung(int? index) => state = index == null
      ? state.copyWith(clearSelection: true)
      : state.copyWith(selectedRung: index);
}

final programProvider = NotifierProvider<ProgramController, ProgramState>(ProgramController.new);

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

  /// Loads [program] from a file: like selecting an example, the runtime restarts in STOP
  /// with clean data. The selected example stays as the baseline; no rung is selected.
  void loadProgram(Program program) => state = ProgramState(
        examples: state.examples,
        selected: state.selected,
        program: program,
        loadCount: state.loadCount + 1,
      );

  /// Replaces the program; the selection is dropped if its rung no longer exists.
  void replaceProgram(Program program) {
    final rung = state.selectedRung;
    state = state.copyWith(
      program: program,
      clearSelection: rung != null && rung >= program.rungs.length,
    );
  }

  /// Replaces the whole rack configuration.
  void setChassis(ChassisConfig chassis) =>
      replaceProgram(state.program.copyWith(chassis: chassis));

  /// Mounts [module] in [slot] (slot 0 takes only a CPU).
  void setChassisSlot(int slot, ModuleDefinition module) =>
      setChassis(state.program.chassis.setSlot(slot, module));

  /// Empties [slot].
  void clearChassisSlot(int slot) => setChassis(state.program.chassis.clearSlot(slot));

  /// Maps the main digital inputs (input tiles) to the module in [slot].
  void setDigitalInputSlot(int slot) =>
      _mapIo((m) => m.copyWith(digitalInputSlot: slot));

  /// Maps the main digital outputs (lamp tiles) to the module in [slot].
  void setDigitalOutputSlot(int slot) =>
      _mapIo((m) => m.copyWith(digitalOutputSlot: slot));

  /// Maps the analog inputs to the module in [slot].
  void setAnalogInputSlot(int slot) =>
      _mapIo((m) => m.copyWith(analogInputSlot: slot));

  /// Maps the analog outputs to the module in [slot].
  void setAnalogOutputSlot(int slot) =>
      _mapIo((m) => m.copyWith(analogOutputSlot: slot));

  void _mapIo(IoMappingConfig Function(IoMappingConfig) change) =>
      replaceProgram(
        state.program.copyWith(ioMapping: change(state.program.ioMapping)),
      );

  /// Connects the thumbwheel to the digital input module in [slot].
  void setThumbwheelSlot(int slot) =>
      _mapIo((m) => m.copyWith(thumbwheelSlot: slot));

  /// Connects the 7-segment display to the digital output module in [slot].
  void setSevenSegmentSlot(int slot) =>
      _mapIo((m) => m.copyWith(sevenSegmentSlot: slot));

  /// Selects the rung at [index]; null clears the selection.
  void selectRung(int? index) => state = index == null
      ? state.copyWith(clearSelection: true)
      : state.copyWith(selectedRung: index);
}

final programProvider = NotifierProvider<ProgramController, ProgramState>(ProgramController.new);

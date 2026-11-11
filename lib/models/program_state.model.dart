import 'package:plc_core/plc_core.dart';

import 'ladder_example.model.dart';

class ProgramState {
  ProgramState({
    required this.examples,
    this.selected = 0,
    Program? program,
    this.selectedRung,
    this.loadCount = 0,
    this.activeRoutine = 2,
  }) : program = program ?? examples[selected].program.copyWith();

  final List<LadderExample> examples;
  final int selected;

  /// The program being edited and run; starts as a copy of the selected example's program.
  final Program program;

  /// Index of the selected rung, or null when none is selected.
  final int? selectedRung;

  /// How many program files were loaded; a new value makes the runtime start from clean data.
  final int loadCount;

  /// Program file shown and edited in the ladder view: 2 = main, 3+ = subroutines.
  final int activeRoutine;

  /// Rungs of the active routine.
  List<Rung> get rungs => program.rungsFor(activeRoutine);

  LadderExample get example => examples[selected];

  ProgramState copyWith({
    Program? program,
    int? selectedRung,
    bool clearSelection = false,
    int? activeRoutine,
  }) =>
      ProgramState(
        examples: examples,
        selected: selected,
        program: program ?? this.program,
        selectedRung: clearSelection ? null : (selectedRung ?? this.selectedRung),
        loadCount: loadCount,
        activeRoutine: activeRoutine ?? this.activeRoutine,
      );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/examples.dart';
import '../models/program_state.model.dart';

/// Holds the program shown in the editor (bundled examples for now; editing comes next).
class ProgramController extends Notifier<ProgramState> {
  @override
  ProgramState build() => ProgramState(examples: ladderExamples);

  void select(int index) => state = state.copyWith(selected: index);
}

final programProvider = NotifierProvider<ProgramController, ProgramState>(ProgramController.new);

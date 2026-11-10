import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import 'program.controller.dart';

/// Edits the elements of a rung (instructions and branches) using the plc_core tree edits.
/// Paths and slots follow the plc_core convention (see `edit.dart`).
class ElementEditController extends Notifier<void> {
  @override
  void build() {}

  void insertElement(int rung, List<int> slot, RungElement element) =>
      _edit(rung, (r) => insertAt(r, slot, element));

  /// Adds a new path holding [first] to the branch at [branchPath].
  void addPath(int rung, List<int> branchPath, RungElement first) =>
      _edit(rung, (r) => addBranchPath(r, branchPath, first));

  /// Keeps the instruction's mnemonic and changes its [address]; [timeBase] and [preset]
  /// apply to timers and counters, [source] and [mask] to MOV and MVM.
  void updateInstruction(
    int rung,
    List<int> path,
    String address, {
    TimeBase timeBase = TimeBase.second,
    int preset = 0,
    String source = '',
    String mask = '',
  }) =>
      _edit(rung, (r) {
        final old = elementAt(r, path) as Instruction;
        return replaceAt(
          r,
          path,
          Instruction.create(
            old.mnemonic,
            address,
            timeBase: timeBase,
            preset: preset,
            source: source,
            mask: mask,
          ),
        );
      });

  void deleteElement(int rung, List<int> path) => _edit(rung, (r) => removeAt(r, path));

  void _edit(int rung, Rung Function(Rung) change) {
    final program = ref.read(programProvider).program;
    final rungs = [...program.rungs];
    rungs[rung] = change(rungs[rung]);
    ref.read(programProvider.notifier).replaceProgram(program.copyWith(rungs: rungs));
  }
}

final elementEditProvider =
    NotifierProvider<ElementEditController, void>(ElementEditController.new);

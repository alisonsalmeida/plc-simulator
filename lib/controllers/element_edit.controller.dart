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

  /// Moves the element at [sourcePath] of rung [sourceRung] to [targetSlot] of rung [targetRung].
  /// Inserts first so [targetSlot] stays valid, then removes the source at its shifted path.
  void moveElement(int sourceRung, List<int> sourcePath, int targetRung, List<int> targetSlot) =>
      _editRungs((rungs) {
        final element = elementAt(rungs[sourceRung], sourcePath);
        rungs[targetRung] = insertAt(rungs[targetRung], targetSlot, element);
        final source = sourceRung == targetRung ? _shiftedByInsert(sourcePath, targetSlot) : sourcePath;
        rungs[sourceRung] = removeAt(rungs[sourceRung], source);
      });

  /// Moves the element at [sourcePath] into a new path of the branch at [branchPath].
  void moveToNewPath(int sourceRung, List<int> sourcePath, int targetRung, List<int> branchPath) =>
      _editRungs((rungs) {
        final element = elementAt(rungs[sourceRung], sourcePath);
        rungs[targetRung] = addBranchPath(rungs[targetRung], branchPath, element);
        rungs[sourceRung] = removeAt(rungs[sourceRung], sourcePath);
      });

  /// Wraps the element at [path] in a branch whose second path holds [parallelElement]
  /// (empty when null), so the two elements sit in parallel.
  void wrapInBranch(int rung, List<int> path, [RungElement? parallelElement]) =>
      _edit(rung, (r) => _wrap(r, path, parallelElement));

  /// Moves the element at [sourcePath] in parallel with the element at [targetPath].
  void moveIntoParallel(int sourceRung, List<int> sourcePath, int targetRung, List<int> targetPath) {
    if (sourceRung == targetRung && _samePath(sourcePath, targetPath)) return;
    _editRungs((rungs) {
      final element = elementAt(rungs[sourceRung], sourcePath);
      rungs[targetRung] = _wrap(rungs[targetRung], targetPath, element);
      var source = sourcePath;
      // The source sat inside the wrapped element: it is now one level deeper.
      if (sourceRung == targetRung && _startsWith(sourcePath, targetPath)) {
        source = [...targetPath, 0, 0, ...sourcePath.skip(targetPath.length)];
      }
      rungs[sourceRung] = removeAt(rungs[sourceRung], source);
    });
  }

  Rung _wrap(Rung rung, List<int> path, RungElement? parallel) => replaceAt(
        rung,
        path,
        Branch([
          [elementAt(rung, path)],
          if (parallel != null) [parallel] else [],
        ]),
      );

  /// Path of an existing element after an element is inserted at [slot].
  List<int> _shiftedByInsert(List<int> path, List<int> slot) {
    final d = slot.length - 1;
    if (path.length <= d || path[d] < slot.last) return path;
    for (var i = 0; i < d; i++) {
      if (path[i] != slot[i]) return path;
    }
    return [...path.take(d), path[d] + 1, ...path.skip(d + 1)];
  }

  bool _samePath(List<int> a, List<int> b) => a.length == b.length && _startsWith(a, b);

  bool _startsWith(List<int> path, List<int> prefix) {
    if (path.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (path[i] != prefix[i]) return false;
    }
    return true;
  }

  /// Keeps the instruction's mnemonic and changes its [address]; [timeBase] and [preset]
  /// apply to timers and counters, [source] and [mask] to MOV and MVM, [offset] to SCL.
  void updateInstruction(
    int rung,
    List<int> path,
    String address, {
    TimeBase timeBase = TimeBase.second,
    int preset = 0,
    String source = '',
    String mask = '',
    String offset = '',
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
            offset: offset,
          ),
        );
      });

  void deleteElement(int rung, List<int> path) => _edit(rung, (r) => removeAt(r, path));

  void _edit(int rung, Rung Function(Rung) change) =>
      _editRungs((rungs) => rungs[rung] = change(rungs[rung]));

  /// Applies [change] to a copy of the rung list and stores it as one program edit.
  void _editRungs(void Function(List<Rung> rungs) change) {
    final program = ref.read(programProvider).program;
    final rungs = [...program.rungs];
    change(rungs);
    ref.read(programProvider.notifier).replaceProgram(program.copyWith(rungs: rungs));
  }
}

final elementEditProvider =
    NotifierProvider<ElementEditController, void>(ElementEditController.new);

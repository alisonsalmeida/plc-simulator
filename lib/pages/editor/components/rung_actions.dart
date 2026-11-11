import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/element_edit.controller.dart';
import '../../../controllers/rung_edit.controller.dart';
import '../../../models/drag_data.model.dart';
import '../../../theme/ladder_assets.dart';
import 'instruction_dialog.dart';

/// UI flows that turn drops and taps on a rung into controller edits.
class RungActions {
  const RungActions(this.context, this.ref, this.rung, this.program);

  final BuildContext context;
  final WidgetRef ref;
  final int rung;
  final Program program;

  Future<RungElement?> _newElement(String tool) async {
    if (tool == LadderAssets.branch) return const Branch([[], []]);
    final input = await showInstructionDialog(context, mnemonic: tool, chassis: program.chassis);
    if (input == null || !context.mounted) return null;
    final edit = ref.read(rungEditProvider.notifier);
    if (input.symbol.isNotEmpty) edit.setSymbol(input.address, input.symbol);
    if (input.description.isNotEmpty) edit.setDescription(input.address, input.description);
    return Instruction.create(
      tool,
      input.address,
      timeBase: input.timeBase,
      preset: input.preset,
      source: input.source,
      mask: input.mask,
      offset: input.offset,
    );
  }

  Future<void> dropOnSlot(List<int> slot, RungDragData data) async {
    final edit = ref.read(elementEditProvider.notifier);
    if (data.isMove) {
      edit.moveElement(data.sourceRung!, data.sourcePath!, rung, slot);
      return;
    }
    final element = await _newElement(data.tool);
    if (element != null) edit.insertElement(rung, slot, element);
  }

  /// Drops [data] in parallel with the element at [targetPath], wrapping both in a branch.
  Future<void> dropOnParallel(List<int> targetPath, RungDragData data) async {
    final edit = ref.read(elementEditProvider.notifier);
    if (data.isMove) {
      edit.moveIntoParallel(data.sourceRung!, data.sourcePath!, rung, targetPath);
      return;
    }
    if (data.tool == LadderAssets.branch) {
      edit.wrapInBranch(rung, targetPath);
      return;
    }
    final element = await _newElement(data.tool);
    if (element != null) edit.wrapInBranch(rung, targetPath, element);
  }

  Future<void> dropOnNewPath(List<int> branchPath, RungDragData data) async {
    final edit = ref.read(elementEditProvider.notifier);
    if (data.isMove) {
      edit.moveToNewPath(data.sourceRung!, data.sourcePath!, rung, branchPath);
      return;
    }
    final element = await _newElement(data.tool);
    if (element != null) edit.addPath(rung, branchPath, element);
  }

  Future<void> editInstruction(List<int> path, Instruction ins) async {
    final input = await showInstructionDialog(
      context,
      mnemonic: ins.mnemonic,
      chassis: program.chassis,
      address: ins.target,
      symbol: program.symbolOf(ins) ?? '',
      description: program.descriptionOf(ins) ?? '',
      timeBase: switch (ins) {
        TimerInstruction(:final timeBase) => timeBase,
        _ => TimeBase.second,
      },
      preset: switch (ins) {
        TimerInstruction(:final preset) || CounterInstruction(:final preset) => preset,
        ShiftInstruction(:final length) ||
        SequencerInstruction(:final length) ||
        Cop(:final length) ||
        Fll(:final length) ||
        FileControlInstruction(:final length) =>
          length,
        _ => 0,
      },
      source: switch (ins) {
        Mov(:final source) || Mvm(:final source) || Swp(:final source) || Tod(:final source) || Frd(:final source) => source.format(),
        BinaryMathInstruction(:final sourceA) || BinaryLogicInstruction(:final sourceA) => sourceA.format(),
        UnaryMathInstruction(:final source) || Scl(:final source) || Not(:final source) => source.format(),
        CompareInstruction(:final sourceB) => sourceB.format(),
        Lim(:final low) => low.format(),
        BitShiftInstruction(:final bit) => bit.toString(),
        StackLoadInstruction(:final source) => source.format(),
        StackUnloadInstruction(:final dest) => dest.format(),
        Sqo(:final dest) => dest.format(),
        Sqc(:final source) || Sql(:final source) => source.format(),
        Cop(:final source) => source.format(),
        Fll(:final source) => source.format(),
        Ave(:final dest) => dest.format(),
        _ => '',
      },
      mask: switch (ins) {
        Mvm(:final mask) || Sqo(:final mask) || Sqc(:final mask) => mask.format(hex: true),
        Lim(:final high) => high.format(),
        ShiftInstruction(:final control) => control.toString(),
        BinaryMathInstruction(:final sourceB) || BinaryLogicInstruction(:final sourceB) => sourceB.format(),
        Scl(:final rate) => rate.format(),
        _ => '',
      },
      offset: switch (ins) {
        Scl(:final offset) => offset.format(),
        SequencerInstruction(:final control) || FileControlInstruction(:final control) => control.toString(),
        _ => '',
      },
      canDelete: true,
    );
    if (input == null || !context.mounted) return;
    final edit = ref.read(elementEditProvider.notifier);
    if (input.delete) {
      edit.deleteElement(rung, path);
      return;
    }
    edit.updateInstruction(
      rung,
      path,
      input.address,
      timeBase: input.timeBase,
      preset: input.preset,
      source: input.source,
      mask: input.mask,
      offset: input.offset,
    );
    final names = ref.read(rungEditProvider.notifier);
    names.setSymbol(input.address, input.symbol);
    names.setDescription(input.address, input.description);
  }

  /// Edits the title and the comment of the rung in one dialog.
  Future<void> editTitleAndComment() async {
    final current = program.rungs[rung];
    final title = TextEditingController(text: current.title);
    final comment = TextEditingController(text: current.comment);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Título e comentário da linha'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: title,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          TextField(
            controller: comment,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Comentário'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('OK')),
        ],
      ),
    );
    final titleText = title.text.trim();
    final commentText = comment.text.trim();
    title.dispose();
    comment.dispose();
    if (ok != true) return;
    final edit = ref.read(rungEditProvider.notifier);
    edit.setTitle(rung, titleText);
    edit.setComment(rung, commentText);
  }
}

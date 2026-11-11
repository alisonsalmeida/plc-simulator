import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import 'file_words.dart';
import 'grid_cell.dart';

/// O, I, S and B3: one row per word, one column per bit (15 down to 0). Tapping toggles B3
/// bits; tapping an I/O bit opens the force dialog; the status bits belong to the machine.
class BitFileGrid extends ConsumerWidget {
  const BitFileGrid({super.key, required this.file, required this.selected, required this.onSelect});

  final BitFile file;
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _cellW = 26.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(fileWordsProvider(file));
    final editable = file == BitFile.bit;
    final forceable = file == BitFile.input || file == BitFile.output;
    final forces = ref.watch(runtimeProvider.select((s) => s.forces));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridRow(label: '', cells: [
        for (var b = 15; b >= 0; b--) GridCell('$b', width: _cellW, header: true),
      ]),
      for (var w = 0; w < file.words; w++)
        GridRow(label: '${file.prefix}:${file.elementLabel(w)}', cells: [
          for (var b = 15; b >= 0; b--)
            GridCell(
              '${(words[w] >> b) & 1}',
              key: ValueKey('bit-${file.prefix}:${file.elementLabel(w)}/$b'),
              width: _cellW,
              selected: selected == '${file.prefix}:${file.elementLabel(w)}/$b',
              forced: forces.containsKey(BitAddress(file, w, b)),
              onTap: () {
                onSelect('${file.prefix}:${file.elementLabel(w)}/$b');
                final address = BitAddress(file, w, b);
                if (editable) ref.read(dataEditProvider.notifier).toggleBit(address);
                if (forceable) _askForce(context, ref, address, forces[address]);
              },
            ),
        ]),
    ]);
  }

  Future<void> _askForce(BuildContext context, WidgetRef ref, BitAddress address, bool? current) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text('Forçar $address'),
        children: [
          SimpleDialogOption(
            key: const ValueKey('force-on'),
            onPressed: () => Navigator.pop(context, 'on'),
            child: const Text('Forçar ON (1)'),
          ),
          SimpleDialogOption(
            key: const ValueKey('force-off'),
            onPressed: () => Navigator.pop(context, 'off'),
            child: const Text('Forçar OFF (0)'),
          ),
          if (current != null)
            SimpleDialogOption(
              key: const ValueKey('force-clear'),
              onPressed: () => Navigator.pop(context, 'clear'),
              child: const Text('Remover Forçamento'),
            ),
        ],
      ),
    );
    final edit = ref.read(dataEditProvider.notifier);
    switch (choice) {
      case 'on':
        edit.setForce(address, true);
      case 'off':
        edit.setForce(address, false);
      case 'clear':
        edit.setForce(address, null);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../models/radix.model.dart';
import 'file_words.dart';
import 'grid_cell.dart';
import 'word_edit_dialog.dart';

/// N7: rows N7:0, N7:10, N7:20, N7:30 and columns 0 to 9, values in the chosen radix.
/// Tapping a cell asks for a new value.
class IntegerGrid extends ConsumerWidget {
  const IntegerGrid({super.key, required this.radix, required this.selected, required this.onSelect});

  final Radix radix;
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _file = BitFile.integer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(fileWordsProvider(_file));
    final cellW = radix == Radix.binary ? 132.0 : 52.0;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridRow(label: '', cells: [
        for (var c = 0; c < 10; c++) GridCell('$c', width: cellW, header: true),
      ]),
      for (var row = 0; row < _file.words; row += 10)
        GridRow(label: 'N7:$row', cells: [
          for (var c = 0; c < 10; c++)
            if (row + c < _file.words)
              GridCell(
                radix.format(words[row + c]),
                key: ValueKey('cell-N7:${row + c}'),
                width: cellW,
                selected: selected == 'N7:${row + c}',
                onTap: () async {
                  final address = 'N7:${row + c}';
                  onSelect(address);
                  final value = await showWordEditDialog(
                    context,
                    address: address,
                    value: words[row + c],
                    radix: radix,
                  );
                  if (value != null) {
                    ref.read(dataEditProvider.notifier).writeWord(WordAddress.parse(address), value);
                  }
                },
              )
            else
              GridCell('', width: cellW),
        ]),
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import 'file_words.dart';
import 'grid_cell.dart';

/// O, I, S and B3: one row per word, one column per bit (15 down to 0). Only B3 bits can be
/// toggled by tapping; the I/O and status bits belong to the machine.
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
              onTap: () {
                onSelect('${file.prefix}:${file.elementLabel(w)}/$b');
                if (editable) ref.read(dataEditProvider.notifier).toggleBit(BitAddress(file, w, b));
              },
            ),
        ]),
    ]);
  }
}

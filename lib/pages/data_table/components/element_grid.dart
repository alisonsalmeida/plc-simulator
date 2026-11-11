import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../models/radix.model.dart';
import 'file_words.dart';
import 'grid_cell.dart';
import 'word_edit_dialog.dart';

/// T4, C5 and R6: one row per element, one column per status bit, then PRE and ACC (LEN and POS for R6). The
/// status bits are driven by the instruction; PRE and ACC can be edited.
class ElementGrid extends ConsumerWidget {
  const ElementGrid({super.key, required this.file, required this.selected, required this.onSelect});

  final BitFile file;
  final String? selected;
  final ValueChanged<String> onSelect;

  static const _cellW = 44.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(fileWordsProvider(file));
    final bits = file.bitNames.entries.toList();
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      GridRow(label: '', cells: [
        for (final b in bits) GridCell(b.key, width: _cellW, header: true),
        GridCell(file == BitFile.control ? 'LEN' : 'PRE', width: _cellW, header: true),
        GridCell(file == BitFile.control ? 'POS' : 'ACC', width: _cellW, header: true),
      ]),
      for (var e = 0; e < file.elements; e++)
        GridRow(label: '${file.prefix}:$e', cells: [
          for (final b in bits)
            GridCell('${(words[file.wordIndex(e)] >> b.value) & 1}', width: _cellW),
          for (final field in const [WordField.pre, WordField.acc])
            _word(context, ref, words, WordAddress(file, e, field)),
        ]),
    ]);
  }

  Widget _word(BuildContext context, WidgetRef ref, FileWords words, WordAddress address) =>
      GridCell(
        '${toInt16(words[address.index])}',
        key: ValueKey('cell-$address'),
        width: _cellW,
        selected: selected == address.toString(),
        onTap: () async {
          onSelect(address.toString());
          final value = await showWordEditDialog(
            context,
            address: address.toString(),
            value: words[address.index],
            radix: Radix.decimal,
          );
          if (value != null) ref.read(dataEditProvider.notifier).writeWord(address, value);
        },
      );
}

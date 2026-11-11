import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../models/runtime_state.model.dart';
import 'file_words.dart';
import 'grid_cell.dart';

/// F8: rows F8:0 and F8:10 and columns 0 to 9, 32-bit float values (two words each).
/// Tapping a cell asks for a new value.
class FloatGrid extends ConsumerWidget {
  const FloatGrid({super.key, required this.selected, required this.onSelect});

  final String? selected;
  final ValueChanged<String> onSelect;

  static const _file = BitFile.float;

  static double _decode(FileWords words, int element) =>
      (ByteData(4)
            ..setUint16(0, words[element * 2], Endian.little)
            ..setUint16(2, words[element * 2 + 1], Endian.little))
          .getFloat32(0, Endian.little);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(fileWordsProvider(_file));
    const cellW = 72.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridRow(
          label: '',
          cells: [
            for (var c = 0; c < 10; c++)
              GridCell('$c', width: cellW, header: true),
          ],
        ),
        for (var row = 0; row < _file.elements; row += 10)
          GridRow(
            label: 'F8:$row',
            cells: [
              for (var c = 0; c < 10; c++)
                if (row + c < _file.elements)
                  GridCell(
                    formatFloat(_decode(words, row + c)),
                    key: ValueKey('cell-F8:${row + c}'),
                    width: cellW,
                    selected: selected == 'F8:${row + c}',
                    onTap: () async {
                      final address = 'F8:${row + c}';
                      onSelect(address);
                      final value = await showDialog<double>(
                        context: context,
                        builder: (_) => _FloatEditDialog(
                          address: address,
                          value: _decode(words, row + c),
                        ),
                      );
                      if (value != null) {
                        ref
                            .read(dataEditProvider.notifier)
                            .writeFloat(WordAddress.parse(address), value);
                      }
                    },
                  )
                else
                  const GridCell('', width: cellW),
            ],
          ),
      ],
    );
  }
}

class _FloatEditDialog extends StatefulWidget {
  const _FloatEditDialog({required this.address, required this.value});

  final String address;
  final double value;

  @override
  State<_FloatEditDialog> createState() => _FloatEditDialogState();
}

class _FloatEditDialogState extends State<_FloatEditDialog> {
  late final _text = TextEditingController(text: formatFloat(widget.value));
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = double.tryParse(_text.text.trim().replaceAll(',', '.'));
    if (value == null) {
      setState(() => _error = 'Valor inválido (ex.: 12.5)');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.address),
    content: TextField(
      controller: _text,
      autofocus: true,
      decoration: InputDecoration(labelText: 'Valor (real)', errorText: _error),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('OK')),
    ],
  );
}

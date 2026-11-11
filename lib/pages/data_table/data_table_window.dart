import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../controllers/data_table.controller.dart';
import '../../models/radix.model.dart';
import '../../theme/app_theme.dart';
import 'components/bit_file_grid.dart';
import 'components/element_grid.dart';
import 'components/float_grid.dart';
import 'components/grid_cell.dart';
import 'components/integer_grid.dart';

/// RSLogix style "Data File" window: a title bar, the list of data files on the left and
/// the grid of the selected file. Self-contained; it only needs a [ProviderScope].
class DataTableWindow extends ConsumerStatefulWidget {
  const DataTableWindow({super.key});

  @override
  ConsumerState<DataTableWindow> createState() => _DataTableWindowState();
}

class _DataTableWindowState extends ConsumerState<DataTableWindow> {
  String? _selected;

  static const _names = {
    BitFile.output: 'OUTPUT',
    BitFile.input: 'INPUT',
    BitFile.status: 'STATUS',
    BitFile.bit: 'BINARY',
    BitFile.timer: 'TIMER',
    BitFile.counter: 'COUNTER',
    BitFile.integer: 'INTEGER',
    BitFile.float: 'FLOAT',
  };

  /// File numbers as RSLogix numbers them (O0, I1, S2, B3, T4, C5, N7).
  static String _id(BitFile f) => switch (f) {
        BitFile.output => 'O0',
        BitFile.input => 'I1',
        BitFile.status => 'S2',
        BitFile.float => 'F8',
        _ => f.prefix,
      };

  void _select(String address) => setState(() => _selected = address);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dataTableProvider);
    final controller = ref.read(dataTableProvider.notifier);
    final file = state.file;
    final isInteger = file == BitFile.integer;
    final title = 'Data File ${_id(file)} (${isInteger ? state.radix.tag : (file == BitFile.float ? 'float' : 'bin')}) -- ${_names[file]}';
    final grid = switch (file) {
      BitFile.integer => IntegerGrid(radix: state.radix, selected: _selected, onSelect: _select),
      BitFile.float => FloatGrid(selected: _selected, onSelect: _select),
      BitFile.timer || BitFile.counter =>
        ElementGrid(file: file, selected: _selected, onSelect: _select),
      _ => BitFileGrid(file: file, selected: _selected, onSelect: _select),
    };
    return Material(
      color: const Color(0xFFD4D0C8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 24,
          color: const Color(0xFF000080),
          padding: const EdgeInsets.only(left: 8),
          child: Row(children: [
            Expanded(
              child: Text(
                title,
                textScaler: TextScaler.noScaling,
                style: LadderStyle.text.copyWith(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('data-close'),
              tooltip: 'Fechar',
              padding: EdgeInsets.zero,
              iconSize: 16,
              constraints: const BoxConstraints.tightFor(width: 28, height: 24),
              color: Colors.white,
              icon: const Icon(Icons.close),
              onPressed: controller.hide,
            ),
          ]),
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 120,
              child: ListView(children: [
                for (final f in BitFile.values)
                  InkWell(
                    key: ValueKey('file-${f.prefix}'),
                    onTap: () {
                      controller.selectFile(f);
                      setState(() => _selected = null);
                    },
                    child: Container(
                      height: 20,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      color: f == file ? const Color(0xFF000080) : Colors.white,
                      child: Text(
                        '${_id(f)} - ${_names[f]}',
                        maxLines: 1,
                        textScaler: TextScaler.noScaling,
                        style: gridText.copyWith(color: f == file ? Colors.white : Colors.black),
                      ),
                    ),
                  ),
              ]),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (isInteger)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(children: [
                      Text('Radix:', textScaler: TextScaler.noScaling, style: gridText),
                      const SizedBox(width: 6),
                      DropdownButton<Radix>(
                        key: const ValueKey('radix'),
                        value: state.radix,
                        isDense: true,
                        style: gridText.copyWith(color: Colors.black),
                        items: [
                          for (final r in Radix.values)
                            DropdownMenuItem(value: r, child: Text(r.label)),
                        ],
                        onChanged: (r) => controller.setRadix(r ?? state.radix),
                      ),
                    ]),
                  ),
                Expanded(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.all(6),
                        child: grid,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

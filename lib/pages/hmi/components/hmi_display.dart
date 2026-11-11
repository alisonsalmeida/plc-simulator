import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';
import '../../../models/radix.model.dart';
import '../../data_table/components/word_edit_dialog.dart';

/// Numeric display of a word; a tap opens a dialog to write a new value.
class HmiDisplay extends ConsumerWidget {
  const HmiDisplay({super.key, required this.widget});

  final HmiWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = WordAddress.parse(widget.address);
    final value = ref.watch(runtimeProvider.select((s) => s.word(address)));
    return InkWell(
      onTap: () async {
        final next = await showWordEditDialog(
          context,
          address: widget.address,
          value: value,
          radix: Radix.decimal,
        );
        if (next != null) ref.read(dataEditProvider.notifier).writeWord(address, next);
      },
      child: Container(
        width: 96,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black87,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$value',
          style: const TextStyle(color: Colors.lightGreenAccent, fontSize: 20, fontFamily: 'monospace'),
        ),
      ),
    );
  }
}

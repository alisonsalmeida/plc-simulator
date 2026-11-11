import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';

/// Momentary pushbutton: the bit is 1 while pressed and 0 on release.
class HmiButton extends ConsumerWidget {
  const HmiButton({super.key, required this.widget});

  final HmiWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = BitAddress.parse(widget.address);
    final on = ref.watch(runtimeProvider.select((s) => s.bit(address)));
    final edit = ref.read(dataEditProvider.notifier);
    return Listener(
      key: ValueKey('button-${widget.id}'),
      onPointerDown: (_) => edit.setBit(address, true),
      onPointerUp: (_) => edit.setBit(address, false),
      onPointerCancel: (_) => edit.setBit(address, false),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: on ? Colors.red.shade700 : Colors.red.shade200,
          border: Border.all(color: Colors.black54, width: 2),
        ),
      ),
    );
  }
}

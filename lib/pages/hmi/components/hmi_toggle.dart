import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/data_edit.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';

/// Toggle switch: a tap flips the bit; shows the current state.
class HmiToggle extends ConsumerWidget {
  const HmiToggle({super.key, required this.widget});

  final HmiWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = BitAddress.parse(widget.address);
    final on = ref.watch(runtimeProvider.select((s) => s.bit(address)));
    return InkWell(
      onTap: () => ref.read(dataEditProvider.notifier).toggleBit(address),
      child: Container(
        width: 64,
        height: 64,
        alignment: on ? Alignment.topCenter : Alignment.bottomCenter,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: on ? Colors.green.shade100 : Colors.grey.shade200,
          border: Border.all(color: Colors.black54),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(on ? 'ON' : 'OFF', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

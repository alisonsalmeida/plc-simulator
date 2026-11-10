import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/runtime.controller.dart';
import '../../../models/hmi_state.model.dart';

/// Read-only indicator: green when the bit is 1, grey when 0.
class HmiLamp extends ConsumerWidget {
  const HmiLamp({super.key, required this.widget});

  final HmiWidget widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = BitAddress.parse(widget.address);
    final on = ref.watch(runtimeProvider.select((s) => s.bit(address)));
    return Container(
      key: ValueKey('lamp-${widget.id}-${on ? 'on' : 'off'}'),
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? Colors.green : Colors.grey.shade400,
        border: Border.all(color: Colors.black54, width: 2),
        boxShadow: on ? [BoxShadow(color: Colors.green.shade300, blurRadius: 10)] : null,
      ),
    );
  }
}

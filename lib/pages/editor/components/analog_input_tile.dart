import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/analog_io.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import 'analog_format.dart';

/// One analog input channel (I:1.n): range selector, slider in V / mA and the raw count.
class AnalogInputTile extends ConsumerWidget {
  const AnalogInputTile({super.key, required this.channel});

  final int channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analogIoProvider.select((s) => s.inputRanges[channel]));
    final raw = ref.watch(runtimeProvider.select((s) => s.analogInputs[channel]));
    final address = 'I:$analogInputSlot.$channel';
    final symbol = ref.watch(programProvider.select((s) => s.program.symbols[address]));
    final controller = ref.read(analogIoProvider.notifier);
    final physical = AnalogInput.toPhysical(range, raw).clamp(0.0, range.maxPhysical);
    return AnalogTileFrame(
      address: address,
      symbol: symbol,
      raw: raw,
      selector: AnalogRangeSelector(
        key: ValueKey('analog-in-range-$channel'),
        range: range,
        onChanged: (r) => controller.setInputRange(channel, r),
      ),
      body: Row(children: [
        Expanded(
          child: Slider(
            key: ValueKey('analog-in-slider-$channel'),
            value: physical,
            min: 0,
            max: range.maxPhysical,
            onChanged: (v) => controller.setInputPhysical(channel, v),
          ),
        ),
        SizedBox(
          width: 64,
          child: Text(formatAnalog(physical, range),
              textAlign: TextAlign.right, style: Theme.of(context).textTheme.labelLarge),
        ),
      ]),
    );
  }
}

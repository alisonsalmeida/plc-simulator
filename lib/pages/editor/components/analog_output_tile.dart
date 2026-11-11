import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/analog_io.controller.dart';
import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';
import '../../../theme/app_theme.dart';
import 'analog_chart.dart';
import 'analog_format.dart';

/// One analog output channel (O:2.n): range selector and a read-only gauge in V / mA.
class AnalogOutputTile extends ConsumerWidget {
  const AnalogOutputTile({super.key, required this.channel});

  final int channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(analogIoProvider.select((s) => s.outputRanges[channel]));
    final raw = ref.watch(runtimeProvider.select((s) => s.analogOutputs[channel]));
    final address = 'O:$analogOutputSlot.$channel';
    final symbol = ref.watch(programProvider.select((s) => s.program.symbols[address]));
    final physical = AnalogOutput.toPhysical(range, raw);
    return AnalogTileFrame(
      address: address,
      symbol: symbol,
      raw: raw,
      chart: AnalogWaveformChart(
        value: physical,
        min: 0,
        max: AnalogOutput.maxPhysical(range),
        unit: range.unit,
        color: Colors.amber,
      ),
      selector: AnalogRangeSelector(
        key: ValueKey('analog-out-range-$channel'),
        range: range,
        onChanged: (r) => ref.read(analogIoProvider.notifier).setOutputRange(channel, r),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Expanded(
            child: LinearProgressIndicator(
              key: ValueKey('analog-out-gauge-$channel'),
              value: (physical / AnalogOutput.maxPhysical(range)).clamp(0.0, 1.0),
              minHeight: 10,
              color: AppColors.energized,
            ),
          ),
          SizedBox(
            width: 72,
            child: Text(formatAnalog(physical, range),
                key: ValueKey('analog-out-value-$channel'),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelLarge),
          ),
        ]),
      ),
    );
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../models/analog_io_state.model.dart';
import 'runtime.controller.dart';

/// Ranges of the analog channels and the physical values the student applies to the inputs.
class AnalogIoController extends Notifier<AnalogIoState> {
  @override
  AnalogIoState build() => const AnalogIoState();

  /// Moves analog input [channel] to [physical] volts or milliamps of its current range.
  void setInputPhysical(int channel, double physical) => ref
      .read(runtimeServiceProvider)
      .setAnalogInput(channel, AnalogInput.toRaw(state.inputRanges[channel], physical));

  /// Changes the range of input [channel], keeping the same physical value when it fits.
  void setInputRange(int channel, AnalogRange range) {
    final old = state.inputRanges[channel];
    if (old == range) return;
    final physical = AnalogInput.toPhysical(old, ref.read(runtimeProvider).analogInputs[channel]);
    final ranges = [...state.inputRanges]..[channel] = range;
    state = state.copyWith(inputRanges: ranges);
    setInputPhysical(channel, physical);
  }

  /// Flips the simulated sensor noise of input [channel].
  void toggleNoise(int channel) {
    final noise = [...state.noiseEnabled];
    noise[channel] = !noise[channel];
    state = state.copyWith(noiseEnabled: noise);
    ref.read(runtimeServiceProvider).setAnalogNoise(channel, noise[channel]);
  }

  void setOutputRange(int channel, AnalogRange range) {
    final ranges = [...state.outputRanges]..[channel] = range;
    state = state.copyWith(outputRanges: ranges);
  }
}

final analogIoProvider =
    NotifierProvider<AnalogIoController, AnalogIoState>(AnalogIoController.new);

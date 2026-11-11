import 'package:plc_core/plc_core.dart';

/// Range selected for each analog channel. Defaults suit the bundled analog example:
/// I:1.0 is a 4–20 mA sensor, the other inputs and O:2.0 are 0–10 V, O:2.1 is 4–20 mA.
class AnalogIoState {
  const AnalogIoState({
    this.inputRanges = const [
      AnalogRange.current,
      AnalogRange.voltage,
      AnalogRange.voltage,
      AnalogRange.voltage,
    ],
    this.outputRanges = const [AnalogRange.voltage, AnalogRange.current],
    this.noiseEnabled = const [false, false, false, false],
  });

  /// One range per input channel I:1.0 … I:1.3.
  final List<AnalogRange> inputRanges;

  /// One range per output channel O:2.0, O:2.1.
  final List<AnalogRange> outputRanges;

  /// Whether the simulated sensor noise is on, per input channel.
  final List<bool> noiseEnabled;

  AnalogIoState copyWith({
    List<AnalogRange>? inputRanges,
    List<AnalogRange>? outputRanges,
    List<bool>? noiseEnabled,
  }) =>
      AnalogIoState(
        inputRanges: inputRanges ?? this.inputRanges,
        outputRanges: outputRanges ?? this.outputRanges,
        noiseEnabled: noiseEnabled ?? this.noiseEnabled,
      );
}

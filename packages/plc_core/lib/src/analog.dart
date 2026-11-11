import 'dart:math';

/// Range of an analog channel, SLC 500 style (1746-NI4 inputs, 1746-NO4V / NO4I outputs).
enum AnalogRange {
  voltage('0–10 V', 'V', 10),
  current('4–20 mA', 'mA', 20);

  const AnalogRange(this.label, this.unit, this.maxPhysical);

  final String label;
  final String unit;

  /// Largest value of the input slider in physical units (V or mA).
  final double maxPhysical;
}

/// Raw counts of the analog input module: 0–10 V is 0..32767; 4–20 mA is 3277..16384
/// (0 mA = 0, linear below 4 mA).
abstract final class AnalogInput {
  static const maxVoltageCount = 32767;
  static const minCurrentCount = 3277;
  static const maxCurrentCount = 16384;

  /// Raw count for [physical] volts or milliamps, clamped to the slider range.
  static int toRaw(AnalogRange range, double physical) {
    final p = physical.clamp(0.0, range.maxPhysical);
    switch (range) {
      case AnalogRange.voltage:
        return (p / 10 * maxVoltageCount).round();
      case AnalogRange.current:
        if (p < 4) return (p / 4 * minCurrentCount).round();
        return (minCurrentCount + (p - 4) / 16 * (maxCurrentCount - minCurrentCount)).round();
    }
  }

  /// Volts or milliamps for a raw count (inverse of [toRaw]).
  static double toPhysical(AnalogRange range, int raw) {
    switch (range) {
      case AnalogRange.voltage:
        return raw.clamp(0, maxVoltageCount) / maxVoltageCount * 10;
      case AnalogRange.current:
        final r = raw.clamp(0, maxCurrentCount);
        if (r < minCurrentCount) return r / minCurrentCount * 4;
        return 4 + (r - minCurrentCount) / (maxCurrentCount - minCurrentCount) * 16;
    }
  }
}

/// Raw counts of the analog output module: 0–10 V is 0..32764 (32764 = 10 V); 4–20 mA is
/// 6242..31208 (6242 = 4 mA, 31208 = 20 mA), linear, displayed up to the module's 21 mA.
abstract final class AnalogOutput {
  static const maxCount = 32764;
  static const minCurrentCount = 6242;
  static const maxCurrentCount = 31208;

  /// Volts or milliamps the module drives for a raw count; the count is clamped to 0..32764.
  static double toPhysical(AnalogRange range, int raw) {
    final r = min(max(raw, 0), maxCount);
    switch (range) {
      case AnalogRange.voltage:
        return r / maxCount * 10;
      case AnalogRange.current:
        if (r < minCurrentCount) return r / minCurrentCount * 4;
        return 4 + (r - minCurrentCount) / (maxCurrentCount - minCurrentCount) * 16;
    }
  }

  /// Largest physical value shown for [range]: 10 V or 21 mA.
  static double maxPhysical(AnalogRange range) => toPhysical(range, maxCount);
}

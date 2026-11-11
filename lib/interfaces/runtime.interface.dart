import 'package:plc_core/plc_core.dart';

import '../models/runtime_state.model.dart';

/// A PLC runtime the editor drives: simulated in the app today, ESP32 hardware later.
abstract class IRuntimeService {
  RuntimeState get current;
  Stream<RuntimeState> get states;

  /// Loads a program and goes to STOP with all inputs off. With [keepData] the N7, B3, T4
  /// and C5 words of the previous program stay as they were.
  void load(Program program, {bool keepData = false});
  void run();
  void step();
  void stop();
  void setInput(int bit, bool value);

  /// Sets the raw count of analog input [channel] (I:1.0 .. I:1.3); it stays until changed.
  void setAnalogInput(int channel, int raw);

  /// Turns the simulated sensor noise of analog input [channel] on or off.
  void setAnalogNoise(int channel, bool enabled);

  /// Writes a data table word (the low 16 bits of [value]); works in STOP and RUN.
  void writeWord(WordAddress address, int value);

  /// Writes a 32-bit float to the `F8` element at [address]; works in STOP and RUN.
  void writeFloat(WordAddress address, double value);

  /// Flips one data table bit; works in STOP and RUN.
  void toggleBit(BitAddress address);

  /// Sets one data table bit to [value]; works in STOP and RUN.
  void setBit(BitAddress address, bool value);
  void dispose();
}

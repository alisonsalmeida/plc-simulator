import 'package:plc_core/plc_core.dart';

import '../models/runtime_state.model.dart';

/// A PLC runtime the editor drives: simulated in the app today, ESP32 hardware later.
abstract class IRuntimeService {
  RuntimeState get current;
  Stream<RuntimeState> get states;

  /// Loads a program and goes to STOP with all inputs off.
  void load(Program program);
  void run();
  void step();
  void stop();
  void setInput(int bit, bool value);
  void dispose();
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../interfaces/runtime.interface.dart';
import '../models/runtime_state.model.dart';
import '../services/simulation_runtime.service.dart';
import 'program.controller.dart';

final runtimeServiceProvider = Provider<IRuntimeService>((ref) {
  final service = SimulationRuntimeService();
  ref.onDispose(service.dispose);
  return service;
});

class RuntimeController extends Notifier<RuntimeState> {
  late IRuntimeService _service;
  Object? _loadedExample;

  @override
  RuntimeState build() {
    _service = ref.watch(runtimeServiceProvider);
    // Editing the program keeps the data table; picking another example or loading a file
    // starts clean.
    final example = ref.watch(programProvider.select((s) => (s.selected, s.loadCount)));
    _service.load(
      ref.watch(programProvider.select((s) => s.program)),
      keepData: example == _loadedExample,
    );
    _loadedExample = example;
    final sub = _service.states.listen((s) => state = s);
    ref.onDispose(sub.cancel);
    return _service.current;
  }

  void run() => _service.run();
  void step() => _service.step();
  void stop() => _service.stop();
  void setInput(int bit, bool value) => _service.setInput(bit, value);
  void setBit(BitAddress address, bool value) => _service.setBit(address, value);
  void writeWord(WordAddress address, int value) => _service.writeWord(address, value);
  void clearAllForces() => _service.clearAllForces();
}

final runtimeProvider = NotifierProvider<RuntimeController, RuntimeState>(RuntimeController.new);

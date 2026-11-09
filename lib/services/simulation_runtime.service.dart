import 'dart:async';

import 'package:plc_core/plc_core.dart';

import '../interfaces/runtime.interface.dart';
import '../models/runtime_state.model.dart';

/// Runs the [ScanEngine] inside the app on a periodic timer.
class SimulationRuntimeService implements IRuntimeService {
  SimulationRuntimeService({this.scanPeriod = const Duration(milliseconds: 10)});

  final Duration scanPeriod;
  final _states = StreamController<RuntimeState>.broadcast();
  ScanEngine? _engine;
  Timer? _timer;
  RuntimeState _state = const RuntimeState();

  @override
  RuntimeState get current => _state;

  @override
  Stream<RuntimeState> get states => _states.stream;

  @override
  void load(Program program) {
    _timer?.cancel();
    _engine = ScanEngine(program);
    _emit(const RuntimeState());
  }

  @override
  void run() {
    if (_state.mode == RuntimeMode.run) return;
    if (_state.mode == RuntimeMode.stop) _engine!.prescan();
    _timer = Timer.periodic(scanPeriod, (_) => _scan());
    _emit(_state.copyWith(mode: RuntimeMode.run));
  }

  @override
  void step() {
    _timer?.cancel();
    if (_state.mode == RuntimeMode.stop) _engine!.prescan();
    _state = _state.copyWith(mode: RuntimeMode.step);
    _scan();
  }

  @override
  void stop() {
    _timer?.cancel();
    _engine!.stop();
    _emit(_state.copyWith(mode: RuntimeMode.stop, outputs: 0, powerFlow: const []));
  }

  @override
  void setInput(int bit, bool value) {
    final mask = 1 << bit;
    final inputs = value ? _state.inputs | mask : _state.inputs & ~mask;
    _engine!.inputImage = inputs;
    _emit(_state.copyWith(inputs: inputs));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _states.close();
  }

  void _scan() {
    final trace = _engine!.scan();
    _emit(_state.copyWith(
      outputs: _engine!.outputImage,
      powerFlow: trace.rungs,
      scanCount: _state.scanCount + 1,
    ));
  }

  void _emit(RuntimeState s) {
    _state = s;
    _states.add(s);
  }
}

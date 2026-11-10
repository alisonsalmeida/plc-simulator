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
  final _clock = Stopwatch();
  Duration _lastScanAt = Duration.zero;
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
    _clock
      ..reset()
      ..start();
    _lastScanAt = Duration.zero;
    // Timers advance by the real time that passed between scans.
    _timer = Timer.periodic(scanPeriod, (_) {
      final now = _clock.elapsed;
      final elapsed = now - _lastScanAt;
      _lastScanAt = now;
      _scan(elapsed);
    });
    _emit(_state.copyWith(mode: RuntimeMode.run));
  }

  @override
  void step() {
    _timer?.cancel();
    _clock.stop();
    if (_state.mode == RuntimeMode.stop) _engine!.prescan();
    _state = _state.copyWith(mode: RuntimeMode.step);
    // STEP is one scan that counts as a fixed 10 ms, so timers advance predictably.
    _scan(const Duration(milliseconds: 10));
  }

  @override
  void stop() {
    _timer?.cancel();
    _clock.stop();
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

  void _scan(Duration elapsed) {
    final trace = _engine!.scan(elapsed: elapsed);
    _emit(_state.copyWith(
      outputs: _engine!.outputImage,
      powerFlow: trace.rungs,
      scanCount: _state.scanCount + 1,
      data: {
        for (final f in BitFile.values)
          f: [for (var w = 0; w < f.words; w++) _engine!.memory.word(f, w)],
      },
    ));
  }

  void _emit(RuntimeState s) {
    _state = s;
    _states.add(s);
  }
}

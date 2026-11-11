import 'dart:async';
import 'dart:math';

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

  /// Slider values before noise, and which channels have simulated sensor noise on.
  final _baseAnalogInputs = List<int>.filled(analogInputChannels, 0);
  final _noiseEnabled = List<bool>.filled(analogInputChannels, false);
  final _random = Random();

  /// Full scale of an analog count and the noise amplitude (about 2 % of it).
  static const _analogMax = 32767;
  static const _noiseAmplitude = 500;

  /// Files whose contents survive editing the program.
  static const _keptFiles = [BitFile.bit, BitFile.timer, BitFile.counter, BitFile.control, BitFile.integer, BitFile.float];

  @override
  RuntimeState get current => _state;

  @override
  Stream<RuntimeState> get states => _states.stream;

  @override
  void load(Program program, {bool keepData = false}) {
    _timer?.cancel();
    final previous = _engine;
    _engine = ScanEngine(program);
    if (keepData && previous != null) _engine!.memory.copyFrom(previous.memory, _keptFiles);
    _emit(RuntimeState(data: keepData ? _snapshot() : const {}));
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
    _emit(_state.copyWith(
      mode: RuntimeMode.stop,
      outputs: 0,
      analogOutputs: List.filled(analogOutputChannels, 0),
      powerFlow: const [],
    ));
  }

  @override
  void setInput(int bit, bool value) {
    final mask = 1 << bit;
    final inputs = value ? _state.inputs | mask : _state.inputs & ~mask;
    _engine!.inputImage = inputs;
    _emit(_state.copyWith(inputs: inputs));
  }

  @override
  void setAnalogInput(int channel, int raw) {
    final value = raw & 0xFFFF;
    _baseAnalogInputs[channel] = value;
    if (!_noiseEnabled[channel]) _applyAnalogInput(channel, value);
    _emit(_state.copyWith(
      analogInputs: [..._engine!.analogInputImage],
      data: _snapshot(),
    ));
  }

  @override
  void setAnalogNoise(int channel, bool enabled) {
    _noiseEnabled[channel] = enabled;
    if (enabled) return;
    _applyAnalogInput(channel, _baseAnalogInputs[channel]);
    _emit(_state.copyWith(
      analogInputs: [..._engine!.analogInputImage],
      data: _snapshot(),
    ));
  }

  void _applyAnalogInput(int channel, int value) {
    _engine!.analogInputImage[channel] = value;
    _engine!.memory.setWord(
      BitFile.input,
      ioElement(BitFile.input, _engine!.program.ioMapping.analogInputSlot, channel) ?? (1 + channel),
      value,
    );
  }

  @override
  void writeWord(WordAddress address, int value) {
    if (_isAnalogInput(address.file, address.element)) {
      return setAnalogInput(address.element - 1, value);
    }
    _engine!.memory.writeWord(address, value);
    _emit(_state.copyWith(data: _snapshot()));
  }

  @override
  void writeFloat(WordAddress address, double value) {
    _engine!.memory.writeFloat(address, value);
    _emit(_state.copyWith(data: _snapshot()));
  }

  @override
  void toggleBit(BitAddress address) {
    if (_isPhysicalInput(address)) return setInput(address.bit, !_state.input(address.bit));
    if (_isAnalogInput(address.file, address.word)) return _flipAnalogBit(address, null);
    final memory = _engine!.memory;
    memory.writeBit(address, !memory.readBit(address));
    _emit(_state.copyWith(data: _snapshot()));
  }

  @override
  void setBit(BitAddress address, bool value) {
    if (_isPhysicalInput(address)) return setInput(address.bit, value);
    if (_isAnalogInput(address.file, address.word)) return _flipAnalogBit(address, value);
    _engine!.memory.writeBit(address, value);
    _emit(_state.copyWith(data: _snapshot()));
  }

  @override
  void setForce(BitAddress address, bool? value) {
    _engine!.setForce(address, value);
    _emitForces();
  }

  @override
  void clearAllForces() {
    _engine!.clearAllForces();
    _emitForces();
  }

  void _emitForces() => _emit(_state.copyWith(
        forces: Map.unmodifiable(_engine!.forces),
        outputs: _engine!.outputImage,
        data: _snapshot(),
      ));

  @override
  void dispose() {
    _timer?.cancel();
    _states.close();
  }

  /// The mapped digital input word is overwritten by the input image every scan, so writes go
  /// through [setInput].
  bool _isPhysicalInput(BitAddress a) {
    final slot = _engine!.program.ioMapping.digitalInputSlot;
    return a.file == BitFile.input &&
        a.word == (ioElement(BitFile.input, slot, null) ?? 0);
  }

  /// I:1.x words are overwritten by the analog input image every scan, so writes go
  /// through [setAnalogInput].
  bool _isAnalogInput(BitFile file, int element) => file == BitFile.input && element >= 1 && element <= 4;

  /// Sets analog input bit [a] to [value], or flips it when [value] is null.
  void _flipAnalogBit(BitAddress a, bool? value) {
    final channel = a.word - 1;
    final word = _engine!.analogInputImage[channel];
    final mask = 1 << a.bit;
    final on = value ?? (word & mask == 0);
    setAnalogInput(channel, on ? word | mask : word & ~mask);
  }

  void _scan(Duration elapsed) {
    for (var c = 0; c < analogInputChannels; c++) {
      if (!_noiseEnabled[c]) continue;
      final jitter = _random.nextInt(2 * _noiseAmplitude + 1) - _noiseAmplitude;
      _applyAnalogInput(c, (_baseAnalogInputs[c] + jitter).clamp(0, _analogMax));
    }
    final trace = _engine!.scan(elapsed: elapsed);
    _emit(_state.copyWith(
      analogInputs: [..._engine!.analogInputImage],
      outputs: _engine!.outputImage,
      analogOutputs: [..._engine!.analogOutputImage],
      powerFlow: trace.rungs,
      scanCount: _state.scanCount + 1,
      data: _snapshot(),
    ));
  }

  Map<BitFile, List<int>> _snapshot() => {
        for (final f in BitFile.values)
          f: [for (var w = 0; w < f.words; w++) _engine!.memory.word(f, w)],
      };

  void _emit(RuntimeState s) {
    _state = s;
    _states.add(s);
  }
}

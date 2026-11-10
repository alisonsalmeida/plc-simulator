import 'address.dart';
import 'memory.dart';
import 'program.dart';

/// `S:1/15` — set during the first scan after going to RUN.
const firstScanBit = BitAddress(BitFile.status, 1, 15);

/// Power flow of one scan: for each rung, the power out of every instruction in traversal
/// order (left to right, branch paths top to bottom).
class ScanTrace {
  const ScanTrace(this.rungs);

  final List<List<bool>> rungs;
}

/// Executes a [Program] scan by scan: read inputs → rungs top to bottom → write outputs.
class ScanEngine {
  ScanEngine(this.program);

  final Program program;
  final PlcMemory memory = PlcMemory();

  /// Physical inputs (I/O panel), copied to `I:0` at the start of each scan.
  int inputImage = 0;

  /// Physical outputs, copied from `O:0` at the end of each scan.
  int outputImage = 0;

  bool _firstScan = true;

  /// Time not yet turned into timer ticks, per timer, in microseconds.
  final Map<ElementAddress, int> _remainder = {};

  /// Called on the transition to RUN: clears non-retentive bits (OTE, TON, TOF), loads
  /// every PRE, arms the first scan. RTO and counters keep their data.
  void prescan() {
    for (final rung in program.rungs) {
      _prescan(rung.elements);
    }
    _firstScan = true;
  }

  /// Called on the transition to STOP: physical outputs go off, the data table is kept.
  void stop() => outputImage = 0;

  /// One scan. [elapsed] is the time since the previous scan; it drives the timers.
  ScanTrace scan({Duration elapsed = Duration.zero}) {
    memory.setWord(BitFile.input, 0, inputImage);
    memory.writeBit(firstScanBit, _firstScan);
    final rungs = <List<bool>>[];
    for (final rung in program.rungs) {
      final trace = <bool>[];
      _series(rung.elements, true, trace, elapsed.inMicroseconds);
      rungs.add(trace);
    }
    outputImage = memory.word(BitFile.output, 0);
    _firstScan = false;
    return ScanTrace(rungs);
  }

  bool _series(List<RungElement> elements, bool power, List<bool> trace, int us) {
    for (final e in elements) {
      power = switch (e) {
        Xic(:final address) => power && memory.readBit(address),
        Xio(:final address) => power && !memory.readBit(address),
        Ote(:final address) => _write(address, power, power),
        Otl(:final address) => power ? _write(address, true, power) : power,
        Otu(:final address) => power ? _write(address, false, power) : power,
        // Every path is evaluated (no short-circuit), so outputs inside branches update.
        Branch(:final paths) =>
          paths.fold(false, (out, path) => _series(path, power, trace, us) || out),
        TimerInstruction() => _timer(e, power, us),
        CounterInstruction() => _counter(e, power),
        Res(:final element) => _reset(element, power),
        WordInstruction() => _move(e, power),
      };
      if (e is Instruction) trace.add(power);
    }
    return power;
  }

  bool _write(BitAddress a, bool value, bool power) {
    memory.writeBit(a, value);
    return power;
  }

  bool _timer(TimerInstruction t, bool power, int us) {
    final el = t.element;
    BitAddress bit(int b) => el.bitAt(b);
    memory.setPre(el, t.preset);
    final tickUs = t.timeBase.milliseconds * 1000;
    // Adds the elapsed time to ACC (capped at PRE); true once ACC has reached PRE.
    bool accumulate() {
      final rem = (_remainder[el] ?? 0) + us;
      final acc = memory.acc(el) + rem ~/ tickUs;
      _remainder[el] = rem % tickUs;
      if (acc >= t.preset) {
        memory.setAcc(el, t.preset);
        _remainder[el] = 0;
        return true;
      }
      memory.setAcc(el, acc);
      return false;
    }

    void clear() {
      memory.writeBit(bit(TimerBit.en), false);
      memory.writeBit(bit(TimerBit.tt), false);
      memory.writeBit(bit(TimerBit.dn), false);
      memory.setAcc(el, 0);
      _remainder[el] = 0;
    }

    switch (t) {
      case Ton():
        if (!power) {
          clear();
        } else {
          memory.writeBit(bit(TimerBit.en), true);
          final done = accumulate();
          memory.writeBit(bit(TimerBit.tt), !done);
          memory.writeBit(bit(TimerBit.dn), done);
        }
      case Rto():
        if (!power) {
          memory.writeBit(bit(TimerBit.en), false);
          memory.writeBit(bit(TimerBit.tt), false);
        } else {
          memory.writeBit(bit(TimerBit.en), true);
          final done = accumulate();
          memory.writeBit(bit(TimerBit.tt), !done);
          memory.writeBit(bit(TimerBit.dn), done);
        }
      case Tof():
        if (power) {
          memory.writeBit(bit(TimerBit.en), true);
          memory.writeBit(bit(TimerBit.dn), true);
          memory.writeBit(bit(TimerBit.tt), false);
          memory.setAcc(el, 0);
          _remainder[el] = 0;
        } else {
          memory.writeBit(bit(TimerBit.en), false);
          if (memory.readBit(bit(TimerBit.dn))) {
            final done = accumulate();
            memory.writeBit(bit(TimerBit.tt), !done);
            memory.writeBit(bit(TimerBit.dn), !done);
          } else {
            memory.writeBit(bit(TimerBit.tt), false);
          }
        }
    }
    return power;
  }

  bool _counter(CounterInstruction c, bool power) {
    final el = c.element;
    memory.setPre(el, c.preset);
    final up = c is Ctu;
    final stored = el.bitAt(up ? CounterBit.cu : CounterBit.cd);
    if (power && !memory.readBit(stored)) {
      final acc = memory.acc(el) + (up ? 1 : -1);
      if (acc > 32767) {
        memory.setAcc(el, -32768);
        memory.writeBit(el.bitAt(CounterBit.ov), true);
      } else if (acc < -32768) {
        memory.setAcc(el, 32767);
        memory.writeBit(el.bitAt(CounterBit.un), true);
      } else {
        memory.setAcc(el, acc);
      }
    }
    memory.writeBit(stored, power);
    memory.writeBit(el.bitAt(CounterBit.dn), memory.acc(el) >= c.preset);
    return power;
  }

  bool _move(WordInstruction w, bool power) {
    if (!power) return power;
    int value(Operand o) => switch (o) {
          Constant(:final value) => value,
          WordAddress() => memory.readWord(o),
        };
    switch (w) {
      case Mov(:final source, :final dest):
        memory.writeWord(dest, value(source));
      case Mvm(:final source, :final mask, :final dest):
        final m = value(mask);
        memory.writeWord(dest, (memory.readWord(dest) & ~m) | (value(source) & m));
      case Clr(:final dest):
        memory.writeWord(dest, 0);
    }
    return power;
  }

  bool _reset(ElementAddress el, bool power) {
    if (power) {
      memory.setAcc(el, 0);
      _remainder[el] = 0;
      for (final bit in el.file.bitNames.values) {
        memory.writeBit(el.bitAt(bit), false);
      }
    }
    return power;
  }

  void _prescan(List<RungElement> elements) {
    for (final e in elements) {
      switch (e) {
        case Ote(:final address):
          memory.writeBit(address, false);
        case Ton(:final element, :final preset):
          memory.setPre(element, preset);
          _reset(element, true);
        case Tof(:final element, :final preset):
          memory.setPre(element, preset);
          _reset(element, true);
          memory.setAcc(element, preset);
        case Rto(:final element, :final preset):
          memory.setPre(element, preset);
        case CounterInstruction(:final element, :final preset):
          memory.setPre(element, preset);
        case Branch(:final paths):
          paths.forEach(_prescan);
        default:
          break;
      }
    }
  }
}

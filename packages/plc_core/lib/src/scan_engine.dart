import 'dart:math';

import 'address.dart';
import 'memory.dart';
import 'program.dart';

/// `S:1/15` — set during the first scan after going to RUN.
const firstScanBit = BitAddress(BitFile.status, 1, 15);

/// Arithmetic flags in `S:0`: carry, overflow, zero, sign.
const carryBit = BitAddress(BitFile.status, 0, 0);
const overflowBit = BitAddress(BitFile.status, 0, 1);
const zeroBit = BitAddress(BitFile.status, 0, 2);
const signBit = BitAddress(BitFile.status, 0, 3);

/// `S:5/0` — minor error: math overflow trap. A real SLC 500 faults the processor when it
/// is set at the end of the scan; this simulator deviates: it only latches the bit until
/// the user clears it, and never faults.
const overflowTrapBit = BitAddress(BitFile.status, 5, 0);

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

  /// Raw counts of the analog input channels (I:1.0 .. I:1.3), copied to the input file at
  /// the start of each scan.
  final List<int> analogInputImage = List.filled(analogInputChannels, 0);

  /// Raw counts of the analog output channels (O:2.0, O:2.1), copied from the output file
  /// at the end of each scan.
  final List<int> analogOutputImage = List.filled(analogOutputChannels, 0);

  /// Forced bits (I:/O: only): an input force overrides the physical input at the start of
  /// each scan, an output force overrides the ladder result at the end of each scan.
  final Map<BitAddress, bool> forces = {};

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

  int get _digitalInputElement =>
      ioElement(BitFile.input, program.ioMapping.digitalInputSlot, null) ?? 0;

  int get _digitalOutputElement =>
      ioElement(BitFile.output, program.ioMapping.digitalOutputSlot, null) ?? 0;

  /// Called on the transition to STOP: physical outputs (digital and analog) go off, the
  /// data table is kept.
  void stop() {
    outputImage = 0;
    analogOutputImage.fillRange(0, analogOutputChannels, 0);
  }

  /// One scan. [elapsed] is the time since the previous scan; it drives the timers.
  ScanTrace scan({Duration elapsed = Duration.zero}) {
    memory.setWord(BitFile.input, _digitalInputElement, inputImage);
    final inSlot = program.ioMapping.analogInputSlot;
    for (var ch = 0; ch < analogInputChannels; ch++) {
      memory.setWord(BitFile.input, ioElement(BitFile.input, inSlot, ch) ?? (1 + ch), analogInputImage[ch]);
    }
    _applyForces(BitFile.input);
    memory.writeBit(firstScanBit, _firstScan);
    final rungs = <List<bool>>[];
    for (final rung in program.rungs) {
      final trace = <bool>[];
      _series(rung.elements, true, trace, elapsed.inMicroseconds);
      rungs.add(trace);
    }
    _applyForces(BitFile.output);
    outputImage = memory.word(BitFile.output, _digitalOutputElement);
    final outSlot = program.ioMapping.analogOutputSlot;
    for (var ch = 0; ch < analogOutputChannels; ch++) {
      analogOutputImage[ch] = memory.word(BitFile.output, ioElement(BitFile.output, outSlot, ch) ?? (1 + ch));
    }
    _firstScan = false;
    return ScanTrace(rungs);
  }

  /// Sets ([value] non-null) or removes ([value] null) the force on [address]; a new force
  /// is written to the data table at once.
  void setForce(BitAddress address, bool? value) {
    if (value == null) {
      forces.remove(address);
      return;
    }
    forces[address] = value;
    memory.writeBit(address, value);
  }

  void clearAllForces() => forces.clear();

  void _applyForces(BitFile file) {
    for (final entry in forces.entries) {
      if (entry.key.file == file) memory.writeBit(entry.key, entry.value);
    }
  }

  bool _series(List<RungElement> elements, bool power, List<bool> trace, int us) {
    for (final e in elements) {
      power = switch (e) {
        Xic(:final address) => power && memory.readBit(address),
        Xio(:final address) => power && !memory.readBit(address),
        Ons(:final address) => _ons(address, power),
        Ote(:final address) => _write(address, power, power),
        Otl(:final address) => power ? _write(address, true, power) : power,
        Otu(:final address) => power ? _write(address, false, power) : power,
        // Every path is evaluated (no short-circuit), so outputs inside branches update.
        Branch(:final paths) =>
          paths.fold(false, (out, path) => _series(path, power, trace, us) || out),
        TimerInstruction() => _timer(e, power, us),
        CounterInstruction() => _counter(e, power),
        Res(:final element) => _reset(element, power),
        BitShiftInstruction() => _bitShift(e, power),
        StackLoadInstruction() => _stackLoad(e, power),
        StackUnloadInstruction() => _stackUnload(e, power),
        SequencerInstruction() => _sequencer(e, power),
        WordInstruction() => _move(e, power),
        CompareInstruction() => power && e.holds(_value),
        Lim() => power && e.holds(_value),
      };
      if (e is Instruction) trace.add(power);
    }
    return power;
  }

  /// One-shot rising: true only on the scan where [power] went from false to true.
  bool _ons(BitAddress address, bool power) {
    final prev = memory.readBit(address);
    memory.writeBit(address, power);
    return power && !prev;
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

  /// Signed value of an operand: the constant itself or the word it addresses.
  int _value(Operand o) => switch (o) {
        Constant(:final value) => value,
        FloatConstant(:final value) => _toInt(value),
        WordAddress(file: BitFile.float) => _toInt(memory.readFloat(o)),
        WordAddress() => memory.readWord(o),
      };

  /// Float value of an operand (integers are converted).
  double _real(Operand o) => switch (o) {
        FloatConstant(:final value) => value,
        WordAddress(file: BitFile.float) => memory.readFloat(o),
        _ => _value(o).toDouble(),
      };

  static bool _isFloat(Operand o) =>
      o is FloatConstant || (o is WordAddress && o.file == BitFile.float);

  /// Nearest signed 16-bit integer of [f] (NaN gives 0).
  static int _toInt(double f) => f.isNaN ? 0 : (f.isInfinite ? f : f.roundToDouble()).clamp(-32768, 32767).toInt();

  bool _move(WordInstruction w, bool power) {
    if (!power) return power;
    final value = _value;
    switch (w) {
      case Mov(:final source, :final dest):
        if (dest.file == BitFile.float) {
          memory.writeFloat(dest, _real(source));
        } else {
          memory.writeWord(dest, value(source));
        }
      case Swp(:final source, :final dest):
        final x = value(source);
        memory.writeWord(dest, (((x & 0xFF) << 8) | ((x >> 8) & 0xFF)).toSigned(16));
      case Tod(:final source, :final dest):
        final val = value(source);
        if (val < 0 || val > 9999) {
          memory.writeBit(overflowBit, true);
          memory.writeBit(overflowTrapBit, true);
        } else {
          var temp = val;
          final d0 = temp % 10;
          temp ~/= 10;
          final d1 = temp % 10;
          temp ~/= 10;
          final d2 = temp % 10;
          temp ~/= 10;
          final d3 = temp % 10;
          final bcd = (d3 << 12) | (d2 << 8) | (d1 << 4) | d0;
          memory.writeWord(dest, bcd);
        }
      case Frd(:final source, :final dest):
        final val = value(source);
        final d3 = (val >> 12) & 0xF;
        final d2 = (val >> 8) & 0xF;
        final d1 = (val >> 4) & 0xF;
        final d0 = val & 0xF;
        if (d3 > 9 || d2 > 9 || d1 > 9 || d0 > 9) {
          memory.writeBit(overflowBit, true);
          memory.writeBit(overflowTrapBit, true);
        } else {
          memory.writeWord(dest, d3 * 1000 + d2 * 100 + d1 * 10 + d0);
        }
      case Mvm(:final source, :final mask, :final dest):
        final m = value(mask);
        memory.writeWord(dest, (memory.readWord(dest) & ~m) | (value(source) & m));
      case Clr(:final dest):
        if (dest.file == BitFile.float) {
          memory.writeFloat(dest, 0);
        } else {
          memory.writeWord(dest, 0);
        }
      case final MathInstruction m:
        _math(m);
      case final LogicInstruction l:
        _logic(l);
    }
    return power;
  }

  /// Runs a bitwise logic instruction on signed 16-bit words and updates `S:0/0..3`
  /// (carry and overflow are cleared).
  void _logic(LogicInstruction l) {
    final v = _value;
    final int result = switch (l) {
      And(:final sourceA, :final sourceB) => (v(sourceA) & v(sourceB)).toSigned(16),
      Or(:final sourceA, :final sourceB) => (v(sourceA) | v(sourceB)).toSigned(16),
      Xor(:final sourceA, :final sourceB) => (v(sourceA) ^ v(sourceB)).toSigned(16),
      Not(:final source) => (~v(source)).toSigned(16),
    };
    memory.writeWord(l.dest, result);
    memory.writeBit(carryBit, false);
    memory.writeBit(overflowBit, false);
    memory.writeBit(zeroBit, result == 0);
    memory.writeBit(signBit, result < 0);
  }

  /// Runs a math instruction and updates `S:0/0..3`. A result outside 16 bits is clamped to
  /// 32767 / -32768 and sets overflow (S:0/1) and the trap bit S:5/0. The math register
  /// S:13 / S:14 is not modelled.
  void _math(MathInstruction m) {
    if (m.dest.file == BitFile.float || m.operands.any(_isFloat)) return _floatMath(m);
    final v = _value;
    var carry = false;
    var overflow = false;
    int result;
    switch (m) {
      case Add(:final sourceA, :final sourceB):
        result = v(sourceA) + v(sourceB);
        carry = (v(sourceA) & 0xFFFF) + (v(sourceB) & 0xFFFF) > 0xFFFF;
      case Sub(:final sourceA, :final sourceB):
        result = v(sourceA) - v(sourceB);
        carry = (v(sourceA) & 0xFFFF) < (v(sourceB) & 0xFFFF);
      case Mul(:final sourceA, :final sourceB):
        result = v(sourceA) * v(sourceB);
      case Div(:final sourceA, :final sourceB):
        final b = v(sourceB);
        if (b == 0) {
          result = 32767;
          overflow = true;
        } else {
          result = _roundedDiv(v(sourceA), b);
        }
      case Neg(:final source):
        result = -v(source);
      case Sqr(:final source):
        final x = v(source);
        carry = x < 0;
        result = sqrt(x.abs()).round();
      case Scl(:final source, :final rate, :final offset):
        result = _roundedDiv(v(source) * v(rate) + v(offset) * 10000, 10000);
      case Mod(:final sourceA, :final sourceB):
        final b = v(sourceB);
        if (b == 0) {
          result = 0;
          overflow = true;
        } else {
          result = v(sourceA) % b;
        }
      case Xpy(:final sourceA, :final sourceB):
        final p = pow(v(sourceA).toDouble(), v(sourceB).toDouble()).toDouble();
        if (p.isNaN) {
          result = 0;
          overflow = true;
        } else {
          // Out-of-range (or infinite) results are clamped below.
          result = p.isInfinite || p.abs() > 1e9 ? (p > 0 ? 32768 : -32769) : p.round();
        }
    }
    if (result > 32767 || result < -32768) {
      result = result > 0 ? 32767 : -32768;
      overflow = true;
    }
    memory.writeWord(m.dest, result);
    memory.writeBit(carryBit, carry);
    memory.writeBit(overflowBit, overflow);
    memory.writeBit(zeroBit, result == 0);
    memory.writeBit(signBit, result < 0);
    if (overflow) memory.writeBit(overflowTrapBit, true);
  }

  /// Math in 32-bit float when the destination or a source is `F8` or a float constant.
  /// A non-float destination receives the rounded, clamped result.
  void _floatMath(MathInstruction m) {
    final r = _real;
    final double result = switch (m) {
      Add(:final sourceA, :final sourceB) => r(sourceA) + r(sourceB),
      Sub(:final sourceA, :final sourceB) => r(sourceA) - r(sourceB),
      Mul(:final sourceA, :final sourceB) => r(sourceA) * r(sourceB),
      Div(:final sourceA, :final sourceB) => r(sourceA) / r(sourceB),
      Mod(:final sourceA, :final sourceB) => r(sourceA) % r(sourceB),
      Xpy(:final sourceA, :final sourceB) => pow(r(sourceA), r(sourceB)).toDouble(),
      Neg(:final source) => -r(source),
      Sqr(:final source) => sqrt(r(source).abs()),
      Scl(:final source, :final rate, :final offset) => r(source) * r(rate) / 10000 + r(offset),
    };
    final carry = m is Sqr && r(m.source) < 0;
    final overflow = result.isNaN || result.isInfinite;
    if (m.dest.file == BitFile.float) {
      memory.writeFloat(m.dest, result);
    } else {
      memory.writeWord(m.dest, _toInt(result));
    }
    memory.writeBit(carryBit, carry);
    memory.writeBit(overflowBit, overflow);
    memory.writeBit(zeroBit, result == 0);
    memory.writeBit(signBit, result < 0);
    if (overflow) memory.writeBit(overflowTrapBit, true);
  }

  /// [n] / [d] rounded to the nearest integer, halves away from zero.
  static int _roundedDiv(int n, int d) {
    final q = (2 * n.abs() + d.abs()) ~/ (2 * d.abs());
    return (n < 0) != (d < 0) ? -q : q;
  }

  /// Bit `i` of the array of [s] (bit 0 is the least significant bit of the first word).
  BitAddress _arrayBit(ShiftInstruction s, int i) =>
      BitAddress(s.array.file, s.array.element + i ~/ 16, i % 16);

  /// BSL / BSR on the rising edge of the rung (EN holds the previous state). The bit that
  /// leaves the array goes to UL.
  bool _bitShift(BitShiftInstruction s, bool power) {
    final c = s.control;
    final en = c.bitAt(ControlBit.en);
    final dn = c.bitAt(ControlBit.dn);
    memory.setLen(c, s.length);
    if (!power) {
      memory.writeBit(en, false);
      memory.writeBit(dn, false);
      return power;
    }
    if (memory.readBit(en)) return power;
    final left = s is Bsl;
    final last = s.length - 1;
    memory.writeBit(c.bitAt(ControlBit.ul), memory.readBit(_arrayBit(s, left ? last : 0)));
    if (left) {
      for (var i = last; i > 0; i--) {
        memory.writeBit(_arrayBit(s, i), memory.readBit(_arrayBit(s, i - 1)));
      }
    } else {
      for (var i = 0; i < last; i++) {
        memory.writeBit(_arrayBit(s, i), memory.readBit(_arrayBit(s, i + 1)));
      }
    }
    memory.writeBit(_arrayBit(s, left ? 0 : last), memory.readBit(s.bit));
    memory.writeBit(en, true);
    memory.writeBit(dn, true);
    return power;
  }

  /// FFL / LFL on the rising edge of the rung (EN holds the previous state): stores the
  /// source at POS; DN when the stack is full.
  bool _stackLoad(StackLoadInstruction s, bool power) {
    final c = s.control;
    final en = c.bitAt(ControlBit.en);
    memory.setLen(c, s.length);
    if (!power) {
      memory.writeBit(en, false);
      return power;
    }
    if (memory.readBit(en)) return power;
    memory.writeBit(en, true);
    final pos = memory.pos(c);
    if (pos < s.length) {
      memory.writeWord(s.word(pos), _value(s.source));
      memory.setPos(c, pos + 1);
      memory.writeBit(c.bitAt(ControlBit.em), false);
      if (pos + 1 >= s.length) memory.writeBit(c.bitAt(ControlBit.dn), true);
    }
    return power;
  }

  /// FFU / LFU on the rising edge of the rung (EU holds the previous state): moves a word to
  /// the destination and decrements POS; EM when the stack is empty.
  bool _stackUnload(StackUnloadInstruction s, bool power) {
    final c = s.control;
    final eu = c.bitAt(ControlBit.eu);
    memory.setLen(c, s.length);
    if (!power) {
      memory.writeBit(eu, false);
      return power;
    }
    if (memory.readBit(eu)) return power;
    memory.writeBit(eu, true);
    final pos = memory.pos(c);
    if (pos > 0) {
      final fifo = s is Ffu;
      memory.writeWord(s.dest, memory.readWord(s.word(fifo ? 0 : pos - 1)));
      if (fifo) {
        for (var i = 1; i < pos; i++) {
          memory.writeWord(s.word(i - 1), memory.readWord(s.word(i)));
        }
      }
      memory.setPos(c, pos - 1);
      memory.writeBit(c.bitAt(ControlBit.dn), false);
      if (pos - 1 == 0) memory.writeBit(c.bitAt(ControlBit.em), true);
    }
    return power;
  }

  /// SQO / SQC / SQL on the rising edge of the rung (EN holds the previous state): advances
  /// POS (wrapping from LEN to 1), sets DN at the last step, then runs the step.
  bool _sequencer(SequencerInstruction s, bool power) {
    final c = s.control;
    final en = c.bitAt(ControlBit.en);
    memory.setLen(c, s.length);
    if (!power) {
      memory.writeBit(en, false);
      return power;
    }
    if (memory.readBit(en)) return power;
    memory.writeBit(en, true);
    var pos = memory.pos(c) + 1;
    if (pos > s.length) pos = 1;
    memory.setPos(c, pos);
    memory.writeBit(c.bitAt(ControlBit.dn), pos == s.length);
    switch (s) {
      case Sqo(:final mask, :final dest):
        final fileVal = memory.readWord(s.word(pos)) & 0xFFFF;
        final maskVal = _value(mask) & 0xFFFF;
        final destVal = memory.readWord(dest) & 0xFFFF;
        memory.writeWord(dest, toInt16((fileVal & maskVal) | (destVal & ~maskVal)));
      case Sqc(:final mask, :final source):
        final maskVal = _value(mask) & 0xFFFF;
        final match = (memory.readWord(s.word(pos)) & maskVal) == (_value(source) & maskVal);
        memory.writeBit(c.bitAt(ControlBit.fd), match);
      case Sql(:final source):
        memory.writeWord(s.word(pos), _value(source));
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

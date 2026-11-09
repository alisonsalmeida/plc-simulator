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

  /// Called on the transition to RUN: clears non-retentive (OTE) bits, arms the first scan.
  void prescan() {
    for (final rung in program.rungs) {
      _clearOte(rung.elements);
    }
    _firstScan = true;
  }

  /// Called on the transition to STOP: physical outputs go off, the data table is kept.
  void stop() => outputImage = 0;

  ScanTrace scan() {
    memory.setWord(BitFile.input, 0, inputImage);
    memory.writeBit(firstScanBit, _firstScan);
    final rungs = <List<bool>>[];
    for (final rung in program.rungs) {
      final trace = <bool>[];
      _series(rung.elements, true, trace);
      rungs.add(trace);
    }
    outputImage = memory.word(BitFile.output, 0);
    _firstScan = false;
    return ScanTrace(rungs);
  }

  bool _series(List<RungElement> elements, bool power, List<bool> trace) {
    for (final e in elements) {
      power = switch (e) {
        Xic(:final address) => power && memory.readBit(address),
        Xio(:final address) => power && !memory.readBit(address),
        Ote(:final address) => _write(address, power, power),
        Otl(:final address) => power ? _write(address, true, power) : power,
        Otu(:final address) => power ? _write(address, false, power) : power,
        // Every path is evaluated (no short-circuit), so outputs inside branches update.
        Branch(:final paths) =>
          paths.fold(false, (out, path) => _series(path, power, trace) || out),
      };
      if (e is Instruction) trace.add(power);
    }
    return power;
  }

  bool _write(BitAddress a, bool value, bool power) {
    memory.writeBit(a, value);
    return power;
  }

  void _clearOte(List<RungElement> elements) {
    for (final e in elements) {
      switch (e) {
        case Ote(:final address):
          memory.writeBit(address, false);
        case Branch(:final paths):
          paths.forEach(_clearOte);
        default:
          break;
      }
    }
  }
}

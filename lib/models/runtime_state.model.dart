import 'package:plc_core/plc_core.dart';

enum RuntimeMode { stop, run, step }

/// Snapshot of the simulated PLC after the last scan.
class RuntimeState {
  const RuntimeState({
    this.mode = RuntimeMode.stop,
    this.inputs = 0,
    this.outputs = 0,
    this.analogInputs = const [0, 0, 0, 0],
    this.analogOutputs = const [0, 0],
    this.powerFlow = const [],
    this.scanCount = 0,
    this.data = const {},
  });

  final RuntimeMode mode;

  /// Physical input and output images (bit n = I:0/n, O:0/n).
  final int inputs;
  final int outputs;

  /// Raw counts of the analog input channels I:1.0 .. I:1.3 and of the analog output
  /// channels O:2.0, O:2.1 (outputs are 0 in STOP).
  final List<int> analogInputs;
  final List<int> analogOutputs;

  /// Per rung, the power out of each instruction in traversal order; empty in STOP.
  final List<List<bool>> powerFlow;
  final int scanCount;

  /// Data table words after the last scan, per file; empty before the first scan.
  final Map<BitFile, List<int>> data;

  bool input(int bit) => (inputs >> bit) & 1 == 1;
  bool output(int bit) => (outputs >> bit) & 1 == 1;

  /// Value of [address] in the data table after the last scan.
  bool bit(BitAddress address) =>
      (_word(address.file, address.file.wordIndex(address.word)) >> address.bit) & 1 == 1;

  /// Preset and accumulated value (signed 16-bit) of a timer/counter after the last scan.
  int pre(ElementAddress e) => toInt16(_word(e.file, e.presetIndex));
  int acc(ElementAddress e) => toInt16(_word(e.file, e.accumIndex));

  /// Value (signed 16-bit) of a word operand after the last scan.
  int word(WordAddress a) => toInt16(_word(a.file, a.index));

  int _word(BitFile file, int index) => data[file]?[index] ?? 0;

  RuntimeState copyWith({
    RuntimeMode? mode,
    int? inputs,
    int? outputs,
    List<int>? analogInputs,
    List<int>? analogOutputs,
    List<List<bool>>? powerFlow,
    int? scanCount,
    Map<BitFile, List<int>>? data,
  }) =>
      RuntimeState(
        mode: mode ?? this.mode,
        inputs: inputs ?? this.inputs,
        outputs: outputs ?? this.outputs,
        analogInputs: analogInputs ?? this.analogInputs,
        analogOutputs: analogOutputs ?? this.analogOutputs,
        powerFlow: powerFlow ?? this.powerFlow,
        scanCount: scanCount ?? this.scanCount,
        data: data ?? this.data,
      );
}

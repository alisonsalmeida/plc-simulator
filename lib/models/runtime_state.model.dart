enum RuntimeMode { stop, run, step }

/// Snapshot of the simulated PLC after the last scan.
class RuntimeState {
  const RuntimeState({
    this.mode = RuntimeMode.stop,
    this.inputs = 0,
    this.outputs = 0,
    this.powerFlow = const [],
    this.scanCount = 0,
  });

  final RuntimeMode mode;

  /// Physical input and output images (bit n = I:0/n, O:0/n).
  final int inputs;
  final int outputs;

  /// Per rung, the power out of each instruction in traversal order; empty in STOP.
  final List<List<bool>> powerFlow;
  final int scanCount;

  bool input(int bit) => (inputs >> bit) & 1 == 1;
  bool output(int bit) => (outputs >> bit) & 1 == 1;

  RuntimeState copyWith({
    RuntimeMode? mode,
    int? inputs,
    int? outputs,
    List<List<bool>>? powerFlow,
    int? scanCount,
  }) =>
      RuntimeState(
        mode: mode ?? this.mode,
        inputs: inputs ?? this.inputs,
        outputs: outputs ?? this.outputs,
        powerFlow: powerFlow ?? this.powerFlow,
        scanCount: scanCount ?? this.scanCount,
      );
}

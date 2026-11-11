enum InputKind { toggle, momentary }

/// Tabs of the I/O panel.
enum IoPanelTab { digital, analog, peripherals }

class IoPanelState {
  const IoPanelState(this.kinds);

  /// One entry per input bit I:0/0 … I:0/15.
  final List<InputKind> kinds;

  IoPanelState copyWith({List<InputKind>? kinds}) => IoPanelState(kinds ?? this.kinds);
}

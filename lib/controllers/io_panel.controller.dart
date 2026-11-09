import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/io_panel_state.model.dart';
import 'program.controller.dart';

class IoPanelController extends Notifier<IoPanelState> {
  @override
  IoPanelState build() {
    final momentary = ref.watch(programProvider.select((s) => s.example.momentaryInputs));
    return IoPanelState([
      for (var bit = 0; bit < 16; bit++)
        momentary.contains(bit) ? InputKind.momentary : InputKind.toggle,
    ]);
  }

  void toggleKind(int bit) {
    final kinds = [...state.kinds];
    kinds[bit] = kinds[bit] == InputKind.toggle ? InputKind.momentary : InputKind.toggle;
    state = state.copyWith(kinds: kinds);
  }
}

final ioPanelProvider = NotifierProvider<IoPanelController, IoPanelState>(IoPanelController.new);

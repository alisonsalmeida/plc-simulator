import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../models/hmi_state.model.dart';

/// Widgets of the Supervisório canvas (in memory only). `add` and `update` return a pt-BR
/// error message, or null when the change was applied.
class HmiController extends Notifier<HmiState> {
  @override
  HmiState build() => const HmiState();

  String? add(HmiKind kind, String address, {String label = '', int min = 0, int max = 100}) {
    final canonical = _validate(kind, address, min, max);
    if (canonical.error != null) return canonical.error;
    final n = state.widgets.length % 10;
    final widget = HmiWidget(
      id: state.nextId,
      kind: kind,
      address: canonical.address!,
      label: label.trim().isEmpty ? canonical.address! : label.trim(),
      x: 16.0 + 24 * n,
      y: 16.0 + 24 * n,
      min: min,
      max: max,
    );
    state = state.copyWith(widgets: [...state.widgets, widget], nextId: state.nextId + 1);
    return null;
  }

  String? update(int id, String address, {String label = '', int min = 0, int max = 100}) {
    final current = state.widgets.firstWhere((w) => w.id == id);
    final canonical = _validate(current.kind, address, min, max);
    if (canonical.error != null) return canonical.error;
    _replace(
      id,
      (w) => w.copyWith(
        address: canonical.address,
        label: label.trim().isEmpty ? canonical.address : label.trim(),
        min: min,
        max: max,
      ),
    );
    return null;
  }

  void move(int id, double x, double y) =>
      _replace(id, (w) => w.copyWith(x: x < 0 ? 0 : x, y: y < 0 ? 0 : y));

  void remove(int id) =>
      state = state.copyWith(widgets: [for (final w in state.widgets) if (w.id != id) w]);

  void _replace(int id, HmiWidget Function(HmiWidget) change) => state = state.copyWith(
        widgets: [for (final w in state.widgets) w.id == id ? change(w) : w],
      );

  ({String? address, String? error}) _validate(HmiKind kind, String text, int min, int max) {
    if (kind == HmiKind.bar && min >= max) {
      return (address: null, error: 'O mínimo deve ser menor que o máximo');
    }
    if (kind.isBit) {
      try {
        return (address: BitAddress.parse(text).toString(), error: null);
      } on FormatException {
        final isWord = _parses(() => WordAddress.parse(text));
        return (
          address: null,
          error: isWord ? 'Use um endereço de bit (ex.: B3:0/0)' : 'Endereço de bit inválido',
        );
      }
    }
    try {
      return (address: WordAddress.parse(text).toString(), error: null);
    } on FormatException {
      final isBit = _parses(() => BitAddress.parse(text));
      return (
        address: null,
        error: isBit ? 'Use um endereço de palavra (ex.: N7:0)' : 'Endereço de palavra inválido',
      );
    }
  }

  bool _parses(void Function() parse) {
    try {
      parse();
      return true;
    } on FormatException {
      return false;
    }
  }
}

final hmiProvider = NotifierProvider<HmiController, HmiState>(HmiController.new);

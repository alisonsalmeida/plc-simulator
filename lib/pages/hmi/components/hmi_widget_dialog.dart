import 'package:flutter/material.dart';

import '../../../models/hmi_state.model.dart';

/// Applies the dialog values; returns a pt-BR error message, or null when accepted.
typedef HmiSubmit = String? Function(String address, String label, int min, int max);

/// Asks for the address, label (and range for a bar) of a widget, for adding or editing.
Future<void> showHmiWidgetDialog(
  BuildContext context, {
  required HmiKind kind,
  HmiWidget? initial,
  required HmiSubmit submit,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _HmiWidgetDialog(kind: kind, initial: initial, submit: submit),
    );

class _HmiWidgetDialog extends StatefulWidget {
  const _HmiWidgetDialog({required this.kind, required this.initial, required this.submit});

  final HmiKind kind;
  final HmiWidget? initial;
  final HmiSubmit submit;

  @override
  State<_HmiWidgetDialog> createState() => _HmiWidgetDialogState();
}

class _HmiWidgetDialogState extends State<_HmiWidgetDialog> {
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _label = TextEditingController(
    text: widget.initial != null && widget.initial!.label != widget.initial!.address
        ? widget.initial!.label
        : '',
  );
  late final _min = TextEditingController(text: '${widget.initial?.min ?? 0}');
  late final _max = TextEditingController(text: '${widget.initial?.max ?? 100}');
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _label.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _ok() {
    final min = int.tryParse(_min.text.trim());
    final max = int.tryParse(_max.text.trim());
    if (widget.kind == HmiKind.bar && (min == null || max == null)) {
      setState(() => _error = 'Mínimo e máximo devem ser números inteiros');
      return;
    }
    final error = widget.submit(_address.text, _label.text, min ?? 0, max ?? 100);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.kind.label),
        content: SizedBox(
          width: 320,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const ValueKey('hmi-address'),
              controller: _address,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Endereço',
                hintText: widget.kind.isBit ? 'B3:0/0' : 'N7:0',
                errorText: _error,
              ),
              onSubmitted: (_) => _ok(),
            ),
            TextField(
              key: const ValueKey('hmi-label'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Rótulo (opcional)'),
            ),
            if (widget.kind == HmiKind.bar)
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('hmi-min'),
                    controller: _min,
                    decoration: const InputDecoration(labelText: 'Mínimo'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('hmi-max'),
                    controller: _max,
                    decoration: const InputDecoration(labelText: 'Máximo'),
                  ),
                ),
              ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _ok, child: const Text('OK')),
        ],
      );
}

import 'package:flutter/material.dart';

import '../../../models/radix.model.dart';

/// Asks for a new value of [address] in [radix]; returns the signed 16-bit value, or null
/// when cancelled.
Future<int?> showWordEditDialog(
  BuildContext context, {
  required String address,
  required int value,
  required Radix radix,
}) =>
    showDialog<int>(
      context: context,
      builder: (_) => _WordEditDialog(address: address, value: value, radix: radix),
    );

class _WordEditDialog extends StatefulWidget {
  const _WordEditDialog({required this.address, required this.value, required this.radix});

  final String address;
  final int value;
  final Radix radix;

  @override
  State<_WordEditDialog> createState() => _WordEditDialogState();
}

class _WordEditDialogState extends State<_WordEditDialog> {
  late final _text = TextEditingController(text: widget.radix.format(widget.value));
  String? _error;

  String get _invalid => switch (widget.radix) {
        Radix.decimal => 'Valor inválido (-32768 a 32767)',
        Radix.hex => 'Valor inválido (0000 a FFFF)',
        Radix.binary => 'Valor inválido (até 16 bits)',
      };

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final value = widget.radix.parse(_text.text);
    if (value == null) {
      setState(() => _error = _invalid);
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.address),
        content: TextField(
          controller: _text,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Valor (${widget.radix.label.toLowerCase()})',
            errorText: _error,
          ),
          onSubmitted: (_) => _submit(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('OK')),
        ],
      );
}

import 'package:flutter/material.dart';
import 'package:plc_core/plc_core.dart';

/// What the user entered in [showInstructionDialog].
class InstructionInput {
  const InstructionInput({required this.address, required this.symbol, this.description = '', this.delete = false});

  final String address;
  final String symbol;
  final String description;
  final bool delete;
}

/// Asks for the address (validated) and optional symbol of an instruction.
/// Returns null when cancelled; [canDelete] adds the "Excluir" button.
Future<InstructionInput?> showInstructionDialog(
  BuildContext context, {
  required String mnemonic,
  String address = '',
  String symbol = '',
  String description = '',
  bool canDelete = false,
}) =>
    showDialog<InstructionInput>(
      context: context,
      builder: (_) => _InstructionDialog(
        mnemonic: mnemonic,
        address: address,
        symbol: symbol,
        description: description,
        canDelete: canDelete,
      ),
    );

class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog({
    required this.mnemonic,
    required this.address,
    required this.symbol,
    required this.description,
    required this.canDelete,
  });

  final String mnemonic;
  final String address;
  final String symbol;
  final String description;
  final bool canDelete;

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  late final _address = TextEditingController(text: widget.address);
  late final _symbol = TextEditingController(text: widget.symbol);
  late final _description = TextEditingController(text: widget.description);
  String? _error;

  @override
  void dispose() {
    _address.dispose();
    _symbol.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final parsed = BitAddress.parse(_address.text);
      Navigator.pop(
        context,
        InstructionInput(
          address: parsed.toString(),
          symbol: _symbol.text.trim(),
          description: _description.text.trim(),
        ),
      );
    } on FormatException {
      setState(() => _error = 'Endereço inválido');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Instrução ${widget.mnemonic}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _address,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Endereço',
              hintText: 'I:0/0',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          TextField(
            controller: _symbol,
            decoration: const InputDecoration(labelText: 'Símbolo (opcional)'),
            onSubmitted: (_) => _submit(),
          ),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
          ),
        ]),
        actions: [
          if (widget.canDelete)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const InstructionInput(address: '', symbol: '', delete: true)),
              child: const Text('Excluir'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _submit, child: const Text('OK')),
        ],
      );
}

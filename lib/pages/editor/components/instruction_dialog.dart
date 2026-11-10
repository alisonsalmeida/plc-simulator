import 'package:flutter/material.dart';
import 'package:plc_core/plc_core.dart';

/// What the user entered in [showInstructionDialog].
class InstructionInput {
  const InstructionInput({
    required this.address,
    required this.symbol,
    this.description = '',
    this.timeBase = TimeBase.second,
    this.preset = 0,
    this.delete = false,
  });

  final String address;
  final String symbol;
  final String description;
  final TimeBase timeBase;
  final int preset;
  final bool delete;
}

/// Asks for the address (validated), optional symbol and, for timers and counters, the
/// time base and preset of an instruction.
/// Returns null when cancelled; [canDelete] adds the "Excluir" button.
Future<InstructionInput?> showInstructionDialog(
  BuildContext context, {
  required String mnemonic,
  String address = '',
  String symbol = '',
  String description = '',
  TimeBase timeBase = TimeBase.second,
  int preset = 0,
  bool canDelete = false,
}) =>
    showDialog<InstructionInput>(
      context: context,
      builder: (_) => _InstructionDialog(
        mnemonic: mnemonic,
        address: address,
        symbol: symbol,
        description: description,
        timeBase: timeBase,
        preset: preset,
        canDelete: canDelete,
      ),
    );

class _InstructionDialog extends StatefulWidget {
  const _InstructionDialog({
    required this.mnemonic,
    required this.address,
    required this.symbol,
    required this.description,
    required this.timeBase,
    required this.preset,
    required this.canDelete,
  });

  final String mnemonic;
  final String address;
  final String symbol;
  final String description;
  final TimeBase timeBase;
  final int preset;
  final bool canDelete;

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  late final _address = TextEditingController(text: widget.address);
  late final _symbol = TextEditingController(text: widget.symbol);
  late final _description = TextEditingController(text: widget.description);
  late final _preset = TextEditingController(text: '${widget.preset}');
  late TimeBase _timeBase = widget.timeBase;
  String? _error;
  String? _presetError;

  bool get _isTimer => const {'TON', 'TOF', 'RTO'}.contains(widget.mnemonic);
  bool get _isCounter => const {'CTU', 'CTD'}.contains(widget.mnemonic);

  String get _hint => switch (widget.mnemonic) {
        'TON' || 'TOF' || 'RTO' => 'T4:0',
        'CTU' || 'CTD' => 'C5:0',
        'RES' => 'T4:0 ou C5:0',
        _ => 'I:0/0',
      };

  @override
  void dispose() {
    _preset.dispose();
    _address.dispose();
    _symbol.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    final preset = int.tryParse(_preset.text.trim());
    final presetOk = !(_isTimer || _isCounter) || (preset != null && preset >= 0 && preset <= maxPreset);
    String? address;
    try {
      address = Instruction.create(widget.mnemonic, _address.text, preset: presetOk ? preset ?? 0 : 0).target;
    } on FormatException {
      address = null;
    }
    setState(() {
      _error = address == null ? 'Endereço inválido' : null;
      _presetError = presetOk ? null : 'Preset inválido (0 a $maxPreset)';
    });
    if (address == null || !presetOk) return;
    Navigator.pop(
      context,
      InstructionInput(
        address: address,
        symbol: _symbol.text.trim(),
        description: _description.text.trim(),
        timeBase: _timeBase,
        preset: preset ?? 0,
      ),
    );
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
              hintText: _hint,
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_isTimer)
            DropdownButtonFormField<TimeBase>(
              initialValue: _timeBase,
              decoration: const InputDecoration(labelText: 'Base de tempo'),
              items: const [
                DropdownMenuItem(value: TimeBase.second, child: Text('1,0 s')),
                DropdownMenuItem(value: TimeBase.centisecond, child: Text('0,01 s')),
              ],
              onChanged: (v) => setState(() => _timeBase = v ?? _timeBase),
            ),
          if (_isTimer || _isCounter)
            TextField(
              controller: _preset,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Preset', errorText: _presetError),
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

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
    this.source = '',
    this.mask = '',
    this.delete = false,
  });

  final String address;
  final String symbol;
  final String description;
  final TimeBase timeBase;
  final int preset;

  /// Operands of word and compare instructions (canonical text). MOV/MVM: source and mask,
  /// [address] is the destination. EQU..GEQ: [address] is Source A, [source] Source B. LIM:
  /// [source] is the low limit, [address] the test value, [mask] the high limit.
  final String source;
  final String mask;
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
  String source = '',
  String mask = '',
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
        source: source,
        mask: mask,
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
    required this.source,
    required this.mask,
    required this.canDelete,
  });

  final String mnemonic;
  final String address;
  final String symbol;
  final String description;
  final TimeBase timeBase;
  final int preset;
  final String source;
  final String mask;
  final bool canDelete;

  @override
  State<_InstructionDialog> createState() => _InstructionDialogState();
}

class _InstructionDialogState extends State<_InstructionDialog> {
  late final _address = TextEditingController(text: widget.address);
  late final _symbol = TextEditingController(text: widget.symbol);
  late final _description = TextEditingController(text: widget.description);
  late final _preset = TextEditingController(text: '${widget.preset}');
  late final _source = TextEditingController(text: widget.source);
  late final _mask = TextEditingController(text: widget.mask);
  late TimeBase _timeBase = widget.timeBase;
  String? _error;
  String? _presetError;
  String? _sourceError;
  String? _maskError;

  bool get _isTimer => const {'TON', 'TOF', 'RTO'}.contains(widget.mnemonic);
  bool get _isWord => const {'MOV', 'MVM', 'CLR'}.contains(widget.mnemonic);
  bool get _isLimit => widget.mnemonic == 'LIM';
  bool get _isCompare => const {'EQU', 'NEQ', 'LES', 'LEQ', 'GRT', 'GEQ'}.contains(widget.mnemonic);
  bool get _hasSource => const {'MOV', 'MVM'}.contains(widget.mnemonic) || _isCompare || _isLimit;
  bool get _hasMask => widget.mnemonic == 'MVM' || _isLimit;
  bool get _isCounter => const {'CTU', 'CTD'}.contains(widget.mnemonic);

  String get _hint => switch (widget.mnemonic) {
        'TON' || 'TOF' || 'RTO' => 'T4:0',
        'CTU' || 'CTD' => 'C5:0',
        'RES' => 'T4:0 ou C5:0',
        'MOV' || 'MVM' || 'CLR' || 'EQU' || 'NEQ' || 'LES' || 'LEQ' || 'GRT' || 'GEQ' => 'N7:0',
        'LIM' => 'N7:0 ou 50',
        _ => 'I:0/0',
      };

  @override
  void dispose() {
    _preset.dispose();
    _source.dispose();
    _mask.dispose();
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
    Operand? source;
    Operand? mask;
    if (_isWord || _isCompare || _isLimit) {
      // The address field is checked on its own; the operands are checked one by one.
      // The test value of LIM may be a constant, the other address fields are word addresses.
      address = _operand(_address.text, true, constant: _isLimit)?.format();
      source = _operand(_source.text, _hasSource);
      mask = _operand(_mask.text, _hasMask, mask: !_isLimit);
    }
    final operandsOk = !(_isWord || _isCompare || _isLimit) || ((!_hasSource || source != null) && (!_hasMask || mask != null));
    setState(() {
      _error = address == null ? 'Endereço inválido' : null;
      _presetError = presetOk ? null : 'Preset inválido (0 a $maxPreset)';
      _sourceError = _hasSource && source == null ? 'Endereço ou valor inválido' : null;
      _maskError = _hasMask && mask == null ? 'Endereço ou valor inválido' : null;
    });
    if (address == null || !presetOk || !operandsOk) return;
    Navigator.pop(
      context,
      InstructionInput(
        address: address,
        symbol: _symbol.text.trim(),
        description: _description.text.trim(),
        timeBase: _timeBase,
        preset: preset ?? 0,
        source: source?.format() ?? '',
        mask: mask?.format(hex: !_isLimit) ?? '',
      ),
    );
  }

  /// The operand typed in [text], or null when it is invalid; skipped fields give null too.
  static Operand? _operand(String text, bool used, {bool mask = false, bool constant = true}) {
    if (!used) return null;
    try {
      return constant ? Operand.parse(text, mask: mask) : WordAddress.parse(text);
    } on FormatException {
      return null;
    }
  }

  Widget _sourceField() => TextField(
        controller: _source,
        autofocus: !_isCompare,
        decoration: InputDecoration(
          labelText: switch (widget.mnemonic) {
            'LIM' => 'Limite inferior',
            'EQU' || 'NEQ' || 'LES' || 'LEQ' || 'GRT' || 'GEQ' => 'Origem B',
            _ => 'Origem',
          },
          hintText: 'N7:0 ou 100',
          errorText: _sourceError,
        ),
        onSubmitted: (_) => _submit(),
      );

  Widget _maskField() => TextField(
        controller: _mask,
        decoration: InputDecoration(
          labelText: _isLimit ? 'Limite superior' : 'Máscara',
          hintText: _isLimit ? 'N7:0 ou 100' : '00FFh',
          errorText: _maskError,
        ),
        onSubmitted: (_) => _submit(),
      );

  Widget _addressField() => TextField(
        controller: _address,
        autofocus: _isCompare || !_hasSource,
        decoration: InputDecoration(
          labelText: _isCompare ? 'Origem A' : (_isLimit ? 'Teste' : (_isWord ? 'Destino' : 'Endereço')),
          hintText: _hint,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Instrução ${widget.mnemonic}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Fields in the order RSLogix shows them.
          if (_isCompare) ...[_addressField(), _sourceField()]
          else if (_isLimit) ...[_sourceField(), _addressField(), _maskField()]
          else ...[
            if (_hasSource) _sourceField(),
            if (_hasMask) _maskField(),
            _addressField(),
          ],
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

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
    this.offset = '',
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

  /// SCL offset. Math instructions: [source] is Source A (the only source of NEG, SQR, SCL),
  /// [mask] is Source B (the SCL rate), [address] is the destination.
  final String offset;
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
  String offset = '',
  bool canDelete = false,
  ChassisConfig? chassis,
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
        offset: offset,
        canDelete: canDelete,
        chassis: chassis,
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
    required this.offset,
    required this.canDelete,
    this.chassis,
  });

  final String mnemonic;
  final String address;
  final String symbol;
  final String description;
  final TimeBase timeBase;
  final int preset;
  final String source;
  final String mask;
  final String offset;
  final bool canDelete;

  /// When set, I/O addresses are checked live against the mounted modules.
  final ChassisConfig? chassis;

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
  late final _offset = TextEditingController(text: widget.offset);
  late TimeBase _timeBase = widget.timeBase;
  String? _error;
  String? _presetError;
  String? _sourceError;
  String? _maskError;
  String? _offsetError;

  /// Why the typed I/O address does not exist in the chassis; null when fine or not an I/O
  /// address (malformed text is left to the submit check).
  String? get _chassisError {
    final text = _address.text.trim();
    if (widget.chassis == null || !RegExp(r'^[IO]:', caseSensitive: false).hasMatch(text)) return null;
    final error = widget.chassis!.validateAddressString(text);
    return error != null && error.startsWith('Endereço inválido') ? null : error;
  }

  bool get _isTimer => const {'TON', 'TOF', 'RTO'}.contains(widget.mnemonic);
  // Logic instructions share the math dialog layout: Source A, Source B, Destination.
  bool get _isMath =>
      const {'ADD', 'SUB', 'MUL', 'DIV', 'NEG', 'SQR', 'SCL', 'AND', 'OR', 'XOR', 'NOT', 'MOD', 'XPY', 'SWP', 'TOD', 'FRD'}.contains(widget.mnemonic);
  bool get _isBinaryMath => const {'ADD', 'SUB', 'MUL', 'DIV', 'AND', 'OR', 'XOR', 'MOD', 'XPY'}.contains(widget.mnemonic);
  bool get _isWord => const {'MOV', 'MVM', 'CLR'}.contains(widget.mnemonic) || _isMath;
  bool get _isLimit => widget.mnemonic == 'LIM';
  bool get _isCompare => const {'EQU', 'NEQ', 'LES', 'LEQ', 'GRT', 'GEQ'}.contains(widget.mnemonic);
  bool get _hasSource => _isShift || const {'MOV', 'MVM'}.contains(widget.mnemonic) || _isCompare || _isLimit || _isMath;
  bool get _hasMask => _isShift || widget.mnemonic == 'MVM' || _isLimit || _isBinaryMath || widget.mnemonic == 'SCL';
  bool get _hasOffset => widget.mnemonic == 'SCL';
  bool get _isShift => const {'BSL', 'BSR', 'FFL', 'FFU', 'LFL', 'LFU'}.contains(widget.mnemonic);
  bool get _isCounter => const {'CTU', 'CTD'}.contains(widget.mnemonic);

  String get _hint => switch (widget.mnemonic) {
        'TON' || 'TOF' || 'RTO' => 'T4:0',
        'CTU' || 'CTD' => 'C5:0',
        'RES' => 'T4:0 ou C5:0',
        'MOV' || 'MVM' || 'CLR' || 'ADD' || 'SUB' || 'MUL' || 'DIV' || 'NEG' || 'SQR' || 'SCL' || 'AND' || 'OR' || 'XOR' || 'NOT' || 'MOD' || 'XPY' || 'SWP' || 'TOD' || 'FRD' || 'EQU' || 'NEQ' || 'LES' || 'LEQ' || 'GRT' || 'GEQ' => 'N7:0',
        'LIM' => 'N7:0 ou 50',
        'BSL' || 'BSR' || 'FFL' || 'FFU' || 'LFL' || 'LFU' => 'B3:0',
        'ONS' => 'B3:0/0',
        _ => 'I:0/0',
      };

  @override
  void dispose() {
    _preset.dispose();
    _source.dispose();
    _mask.dispose();
    _offset.dispose();
    _address.dispose();
    _symbol.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (_chassisError != null) return;
    final preset = int.tryParse(_preset.text.trim());
    final presetOk = _isShift
        ? (preset != null && preset >= 1 && preset <= 128)
        : !(_isTimer || _isCounter) || (preset != null && preset >= 0 && preset <= maxPreset);
    String? address;
    var addressText = _address.text.trim();
    // Bit instructions: a word or analog channel without a bit (I:1.0, N7:0) means bit 0.
    final isBit = !_isShift && !_isWord && !_isCompare && !_isLimit && !_isTimer && !_isCounter && widget.mnemonic != 'RES';
    if (isBit && addressText.isNotEmpty && !addressText.contains('/')) addressText = '$addressText/0';
    try {
      address = _isShift
          ? Instruction.create(widget.mnemonic, addressText,
              source: _source.text.trim(), mask: _mask.text.trim(), preset: presetOk ? preset ?? 0 : 0).target
          : Instruction.create(widget.mnemonic, addressText, preset: presetOk ? preset ?? 0 : 0).target;
    } on FormatException {
      address = null;
    } on ArgumentError {
      address = null;
    }
    Operand? source;
    Operand? mask;
    Operand? offset;
    if (_isWord || _isCompare || _isLimit) {
      // The address field is checked on its own; the operands are checked one by one.
      // The test value of LIM may be a constant, the other address fields are word addresses.
      address = _operand(_address.text, true, constant: _isLimit)?.format();
      source = _operand(_source.text, _hasSource);
      mask = _operand(_mask.text, _hasMask, mask: !_isLimit && !_isMath);
      offset = _operand(_offset.text, _hasOffset);
    }
    final operandsOk = !(_isWord || _isCompare || _isLimit) ||
        ((!_hasSource || source != null) && (!_hasMask || mask != null) && (!_hasOffset || offset != null));
    setState(() {
      _error = address == null ? 'Endereço inválido' : null;
      _presetError = presetOk ? null : (_isShift ? 'Comprimento inválido (1 a 128)' : 'Preset inválido (0 a $maxPreset)');
      _sourceError = _isShift
          ? (address == null ? 'Verifique vetor, controle e bit/operando' : null)
          : (_hasSource && source == null ? 'Endereço ou valor inválido' : null);
      _maskError = _hasMask && !_isShift && mask == null ? 'Endereço ou valor inválido' : null;
      _offsetError = _hasOffset && offset == null ? 'Endereço ou valor inválido' : null;
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
        source: _isShift ? _source.text.trim() : source?.format() ?? '',
        mask: _isShift ? _mask.text.trim() : mask?.format(hex: !_isLimit && !_isMath) ?? '',
        offset: offset?.format() ?? '',
      ),
    );
  }

  /// Enter in a source/mask field: moves on while the address is still empty, else submits.
  void _submitOrNext() => _address.text.trim().isEmpty ? FocusScope.of(context).nextFocus() : _submit();

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
            'BSL' || 'BSR' => 'Bit de entrada',
            'FFL' || 'LFL' => 'Origem',
            'FFU' || 'LFU' => 'Destino',
            'ADD' || 'SUB' || 'MUL' || 'DIV' || 'AND' || 'OR' || 'XOR' || 'MOD' || 'XPY' => 'Origem A',
            'EQU' || 'NEQ' || 'LES' || 'LEQ' || 'GRT' || 'GEQ' => 'Origem B',
            _ => 'Origem',
          },
          hintText: 'N7:0 ou 100',
          errorText: _sourceError,
        ),
        onSubmitted: (_) => _submitOrNext(),
      );

  Widget _maskField() => TextField(
        controller: _mask,
        decoration: InputDecoration(
          labelText: _isShift
              ? 'Controle (R6:n)'
              : _isLimit
              ? 'Limite superior'
              : (_isBinaryMath ? 'Origem B' : (_isMath ? 'Taxa [/10000]' : 'Máscara')),
          hintText: _isShift ? 'R6:0' : (_isLimit || _isMath ? 'N7:0 ou 100' : '00FFh'),
          errorText: _maskError,
        ),
        onSubmitted: (_) => _submitOrNext(),
      );

  Widget _offsetField() => TextField(
        controller: _offset,
        decoration: InputDecoration(
          labelText: 'Deslocamento',
          hintText: 'N7:0 ou 0',
          errorText: _offsetError,
        ),
        onSubmitted: (_) => _submit(),
      );

  Widget _addressField() => TextField(
        controller: _address,
        autofocus: _isCompare || !_hasSource,
        decoration: InputDecoration(
          labelText: _isShift ? 'Vetor' : _isCompare ? 'Origem A' : (_isLimit ? 'Teste' : (_isWord ? 'Destino' : 'Endereço')),
          hintText: _hint,
          errorText: _chassisError ?? _error,
        ),
        onChanged: (_) => setState(() => _error = null),
        onSubmitted: (_) => _submit(),
      );

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Instrução ${widget.mnemonic}'),
        content: SizedBox(width: 400, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Fields in the order RSLogix shows them.
          if (_isCompare) ...[_addressField(), _sourceField()]
          else if (_isLimit) ...[_sourceField(), _addressField(), _maskField()]
          else ...[
            if (_hasSource) _sourceField(),
            if (_hasMask) _maskField(),
            if (_hasOffset) _offsetField(),
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
          if (_isTimer || _isCounter || _isShift)
            TextField(
              controller: _preset,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: _isShift ? 'Comprimento' : 'Preset', errorText: _presetError),
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
        ]))),
        actions: [
          if (widget.canDelete)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, const InstructionInput(address: '', symbol: '', delete: true)),
              child: const Text('Excluir'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: _chassisError == null ? _submit : null, child: const Text('OK')),
        ],
      );
}

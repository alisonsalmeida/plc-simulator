import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:plc_core/plc_core.dart';

import '../../../controllers/program.controller.dart';
import '../../../controllers/runtime.controller.dart';

/// Retro industrial thumbwheel switch with 1..4 BCD digits. Digit `n` drives `I:s/4n..4n+3`,
/// where `s` is the chassis slot it is connected to.
class ThumbwheelTile extends ConsumerStatefulWidget {
  const ThumbwheelTile({super.key});

  @override
  ConsumerState<ThumbwheelTile> createState() => _ThumbwheelTileState();
}

class _ThumbwheelTileState extends ConsumerState<ThumbwheelTile> {
  int _count = 4;

  /// Digit values, index 0 = units.
  final List<int> _digits = [0, 0, 0, 0];

  int? get _slot => ref.read(programProvider).program.ioMapping.thumbwheelSlot;

  void _write(int index, {int? slot, bool clear = false}) {
    final runtime = ref.read(runtimeProvider.notifier);
    final s = slot ?? _slot;
    if (s == null) return;
    final element = ioElement(BitFile.input, s, null);
    if (element == null) return;
    for (var b = 0; b < 4; b++) {
      final address = BitAddress(BitFile.input, element, index * 4 + b);
      runtime.setBit(address, !clear && (_digits[index] >> b) & 1 == 1);
    }
  }

  void _setSlot(int? slot) {
    final old = _slot;
    if (slot == old) return;
    if (old != null) {
      for (var i = 0; i < _count; i++) {
        _write(i, slot: old, clear: true);
      }
    }
    ref.read(programProvider.notifier).setThumbwheelSlot(slot);
    if (slot != null) {
      for (var i = 0; i < _count; i++) {
        _write(i, slot: slot);
      }
    }
  }

  void _change(int index, int delta) {
    setState(() => _digits[index] = (_digits[index] + delta + 10) % 10);
    _write(index);
  }

  void _setCount(int count) {
    final removed = [for (var i = count; i < _count; i++) i];
    setState(() {
      _count = count;
      for (final i in removed) {
        _digits[i] = 0;
      }
    });
    removed.forEach(_write);
  }

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    final program = ref.watch(programProvider.select((s) => s.program));
    final slot = program.ioMapping.thumbwheelSlot;
    final slots = [
      for (var s = 0; s < program.chassis.slots.length; s++)
        if (program.chassis.moduleAt(s).hasDigitalInputs) s,
    ];
    var value = 0;
    var bcd = 0;
    for (var i = _count - 1; i >= 0; i--) {
      value = value * 10 + _digits[i];
      bcd = (bcd << 4) | _digits[i];
    }
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFD8D4C8),
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Thumbwheel (BCD)',
                  style: small?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              DropdownButton<int?>(
                key: const ValueKey('thumbwheel-slot'),
                value: (slot != null && slots.contains(slot)) ? slot : null,
                style: small?.copyWith(color: Colors.black),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('⊘ Não Associado'),
                  ),
                  for (final s in slots)
                    DropdownMenuItem<int?>(value: s, child: Text('Slot $s')),
                ],
                onChanged: _setSlot,
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                key: const ValueKey('thumbwheel-digits'),
                value: _count,
                style: small?.copyWith(color: Colors.black),
                items: [
                  for (var n = 1; n <= 4; n++)
                    DropdownMenuItem(
                      value: n,
                      child: Text('$n dígito${n > 1 ? 's' : ''}'),
                    ),
                ],
                onChanged: (n) => _setCount(n ?? _count),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = _count - 1; i >= 0; i--) _dial(i, slot, small),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Valor: $value  |  BCD: 0x${bcd.toRadixString(16).toUpperCase().padLeft(4, '0')}',
            key: const ValueKey('thumbwheel-summary'),
            style: small?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _dial(int index, int? slot, TextStyle? small) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow('thumbwheel-up-$index', '▲', () => _change(index, 1)),
        Container(
          key: ValueKey('thumbwheel-dial-$index'),
          width: 44,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF111111), Color(0xFF3A3A3A), Color(0xFF111111)],
            ),
            border: Border.all(color: Colors.black87, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '${_digits[index]}',
            style: const TextStyle(
              color: Color(0xFFF2EFE2),
              fontSize: 30,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ),
        _arrow('thumbwheel-down-$index', '▼', () => _change(index, -1)),
        Text(
          slot != null ? 'I:$slot/${index * 4}..${index * 4 + 3}' : '⊘',
          style: small,
        ),
      ],
    ),
  );

  Widget _arrow(String key, String label, VoidCallback onTap) => InkWell(
    key: ValueKey(key),
    onTap: onTap,
    child: SizedBox(width: 44, height: 22, child: Center(child: Text(label))),
  );
}

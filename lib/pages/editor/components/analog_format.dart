import 'package:flutter/material.dart';
import 'package:plc_core/plc_core.dart';

/// Physical value with one decimal and a decimal comma, e.g. `7,5 V` or `12,0 mA`.
String formatAnalog(double value, AnalogRange range) =>
    '${value.toStringAsFixed(1).replaceFirst('.', ',')} ${range.unit}';

/// Compact range selector shared by the analog input and output tiles.
class AnalogRangeSelector extends StatelessWidget {
  const AnalogRangeSelector({super.key, required this.range, required this.onChanged});

  final AnalogRange range;
  final ValueChanged<AnalogRange> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButton<AnalogRange>(
        value: range,
        isDense: true,
        underline: const SizedBox.shrink(),
        style: Theme.of(context).textTheme.labelMedium,
        items: [
          for (final r in AnalogRange.values) DropdownMenuItem(value: r, child: Text(r.label)),
        ],
        onChanged: (r) {
          if (r != null) onChanged(r);
        },
      );
}

/// Frame, address line and raw count shared by the analog tiles; [body] is the control.
class AnalogTileFrame extends StatelessWidget {
  const AnalogTileFrame({
    super.key,
    required this.address,
    required this.symbol,
    required this.selector,
    required this.body,
    required this.raw,
  });

  final String address;
  final String? symbol;
  final Widget selector;
  final Widget body;
  final int raw;

  @override
  Widget build(BuildContext context) {
    final small = Theme.of(context).textTheme.labelSmall;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black26),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(address, style: small?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Expanded(child: Text(symbol ?? '', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
          selector,
        ]),
        body,
        Text('bruto: $raw', style: small),
      ]),
    );
  }
}

import 'package:flutter/material.dart';

/// Number of samples kept in the rolling history.
const analogChartSamples = 40;

/// Oscilloscope-style rolling chart: one sample is appended every time [value] is rebuilt
/// with a new reading (i.e. every scan that changes the channel), so noise shows as jitter.
class AnalogWaveformChart extends StatefulWidget {
  const AnalogWaveformChart({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.unit,
    required this.color,
    this.height = 100,
  });

  final double value;
  final double min;
  final double max;
  final String unit;
  final Color color;
  final double height;

  @override
  State<AnalogWaveformChart> createState() => _AnalogWaveformChartState();
}

class _AnalogWaveformChartState extends State<AnalogWaveformChart> {
  final List<double> _history = [];

  @override
  void initState() {
    super.initState();
    _push();
  }

  @override
  void didUpdateWidget(AnalogWaveformChart old) {
    super.didUpdateWidget(old);
    _push();
  }

  void _push() {
    _history.add(widget.value);
    if (_history.length > analogChartSamples) _history.removeAt(0);
  }

  @override
  Widget build(BuildContext context) {
    final lo = _history.reduce((a, b) => a < b ? a : b);
    final hi = _history.reduce((a, b) => a > b ? a : b);
    final style = Theme.of(context).textTheme.labelSmall;
    String fmt(double v) => '${v.toStringAsFixed(1).replaceFirst('.', ',')} ${widget.unit}';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(
          key: const ValueKey('analog-chart-canvas'),
          size: Size(double.infinity, widget.height),
          painter: _WaveformPainter(List.of(_history), widget.min, widget.max, widget.color),
        ),
      ),
      Text('mín ${fmt(lo)}  máx ${fmt(hi)}  atual ${fmt(widget.value)}', style: style),
    ]);
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.samples, this.min, this.max, this.color);

  final List<double> samples;
  final double min;
  final double max;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF1E222A));
    final grid = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    if (samples.length < 2 || max <= min) return;
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = size.width * i / (analogChartSamples - 1) + size.width * (1 - (samples.length - 1) / (analogChartSamples - 1));
      final t = ((samples[i] - min) / (max - min)).clamp(0.0, 1.0);
      final y = size.height - 3 - t * (size.height - 6);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}

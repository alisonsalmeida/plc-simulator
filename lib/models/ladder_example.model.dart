import 'package:plc_core/plc_core.dart';

/// A bundled example program with the I/O panel setup it expects.
class LadderExample {
  const LadderExample({required this.name, required this.program, this.momentaryInputs = const {}});

  final String name;
  final Program program;

  /// Input bits drawn as push buttons (pressed only while held); the others are switches.
  final Set<int> momentaryInputs;
}

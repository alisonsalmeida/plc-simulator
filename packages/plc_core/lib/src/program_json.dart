import 'chassis.dart';
import 'program.dart';

/// Value of the top-level `format` key of a saved program.
const programJsonFormat = 'plc-simulator-program';

/// Current value of the top-level `version` key.
const programJsonVersion = 1;

/// Serializes [program] to a JSON-encodable map (see [programFromJson] for the shape).
Map<String, Object?> programToJson(Program program) => {
  'format': programJsonFormat,
  'version': programJsonVersion,
  'rungs': [for (final r in program.rungs) _rungToJson(r)],
  'symbols': Map<String, String>.of(program.symbols),
  'descriptions': Map<String, String>.of(program.descriptions),
  'chassis': program.chassis.toJson(),
  'ioMapping': program.ioMapping.toJson(),
};

Map<String, Object?> _rungToJson(Rung rung) => {
  'title': rung.title,
  'comment': rung.comment,
  'elements': [for (final e in rung.elements) _elementToJson(e)],
};

Map<String, Object?> _elementToJson(RungElement element) => switch (element) {
  Branch(:final paths) => {
    'branch': [
      for (final path in paths) [for (final e in path) _elementToJson(e)],
    ],
  },
  Instruction() => _instructionToJson(element),
};

Map<String, Object?> _instructionToJson(Instruction i) {
  final json = <String, Object?>{'op': i.mnemonic, 'address': i.target};
  switch (i) {
    case TimerInstruction(:final timeBase, :final preset):
      json['timeBase'] = timeBase.name;
      json['preset'] = preset;
    case CounterInstruction(:final preset):
      json['preset'] = preset;
    case BitShiftInstruction(:final bit, :final control, :final length):
      json['source'] = bit.toString();
      json['mask'] = control.toString();
      json['preset'] = length;
    case StackLoadInstruction(:final source, :final control, :final length):
      json['source'] = source.toString();
      json['mask'] = control.toString();
      json['preset'] = length;
    case StackUnloadInstruction(:final dest, :final control, :final length):
      json['source'] = dest.toString();
      json['mask'] = control.toString();
      json['preset'] = length;
    case Sqo(:final mask, :final dest, :final control, :final length):
      json['source'] = dest.toString();
      json['mask'] = mask.toString();
      json['offset'] = control.toString();
      json['preset'] = length;
    case Sqc(:final mask, :final source, :final control, :final length):
      json['source'] = source.toString();
      json['mask'] = mask.toString();
      json['offset'] = control.toString();
      json['preset'] = length;
    case Sql(:final source, :final control, :final length):
      json['source'] = source.toString();
      json['offset'] = control.toString();
      json['preset'] = length;
    case Cop(:final source, :final length):
      json['source'] = source.toString();
      json['preset'] = length;
    case Fll(:final source, :final length):
      json['source'] = source.toString();
      json['preset'] = length;
    case Ave(:final dest, :final control, :final length):
      json['source'] = dest.toString();
      json['offset'] = control.toString();
      json['preset'] = length;
    case Srt(:final control, :final length):
      json['offset'] = control.toString();
      json['preset'] = length;
    case Mov(:final source):
      json['source'] = source.toString();
    case Tod(:final source):
      json['source'] = source.toString();
    case Frd(:final source):
      json['source'] = source.toString();
    case Swp(:final source):
      json['source'] = source.toString();
    case Mvm(:final source, :final mask):
      json['source'] = source.toString();
      json['mask'] = mask.toString();
    case BinaryMathInstruction(:final sourceA, :final sourceB):
      json['source'] = sourceA.toString();
      json['mask'] = sourceB.toString();
    case UnaryMathInstruction(:final source):
      json['source'] = source.toString();
    case BinaryLogicInstruction(:final sourceA, :final sourceB):
      json['source'] = sourceA.toString();
      json['mask'] = sourceB.toString();
    case Not(:final source):
      json['source'] = source.toString();
    case Scl(:final source, :final rate, :final offset):
      json['source'] = source.toString();
      json['mask'] = rate.toString();
      json['offset'] = offset.toString();
    case CompareInstruction(:final sourceB):
      json['source'] = sourceB.toString();
    case Lim(:final low, :final high):
      json['source'] = low.toString();
      json['mask'] = high.toString();
    default:
      break;
  }
  return json;
}

/// Builds a program from the map produced by [programToJson]. Instructions go through
/// [Instruction.create], so addresses and operands are validated like in the editor.
///
/// Throws [FormatException] with a descriptive message for a wrong format or version, a
/// missing or mistyped key, an unknown mnemonic or an invalid address.
Program programFromJson(Map<String, Object?> json) {
  final format = json['format'];
  if (format != programJsonFormat) {
    throw FormatException(
      'Unsupported format "$format", expected "$programJsonFormat"',
    );
  }
  final version = json['version'];
  if (version != programJsonVersion) {
    throw FormatException(
      'Unsupported version "$version", expected $programJsonVersion',
    );
  }
  return Program(
    [
      for (final (i, r) in _list(json, 'rungs', 'program').indexed)
        _rungFromJson(_map(r, 'rungs[$i]'), 'rungs[$i]'),
    ],
    symbols: _stringMap(json, 'symbols'),
    descriptions: _stringMap(json, 'descriptions'),
    chassis: switch (json['chassis']) {
      null => ChassisConfig.defaultConfig(),
      final Map<String, Object?> c => ChassisConfig.fromJson(c),
      _ => throw const FormatException('chassis must be an object'),
    },
    ioMapping: switch (json['ioMapping'] ?? json['peripherals']) {
      null => const IoMappingConfig(),
      final Map<String, Object?> m => IoMappingConfig.fromJson(m),
      _ => throw const FormatException('ioMapping must be an object'),
    },
  );
}

Rung _rungFromJson(Map<String, Object?> json, String where) => Rung(
  _elements(_list(json, 'elements', where), '$where.elements'),
  title: _string(json, 'title', where, optional: true),
  comment: _string(json, 'comment', where, optional: true),
);

List<RungElement> _elements(List<Object?> items, String where) => [
  for (final (i, e) in items.indexed)
    _elementFromJson(_map(e, '$where[$i]'), '$where[$i]'),
];

RungElement _elementFromJson(Map<String, Object?> json, String where) {
  if (json.containsKey('branch')) {
    final paths = _list(json, 'branch', where);
    return Branch([
      for (final (p, path) in paths.indexed)
        if (path is List<Object?>)
          _elements(path, '$where.branch[$p]')
        else
          throw FormatException('$where.branch[$p] must be a list'),
    ]);
  }
  final op = _string(json, 'op', where);
  try {
    return Instruction.create(
      op,
      _string(json, 'address', where),
      timeBase: _timeBase(json, where),
      preset: _preset(json, where),
      source: _string(json, 'source', where, optional: true),
      mask: _string(json, 'mask', where, optional: true),
      offset: _string(json, 'offset', where, optional: true),
    );
  } on FormatException catch (e) {
    throw FormatException('$where ($op): ${e.message}${_source(e)}');
  } on ArgumentError catch (e) {
    throw FormatException(
      '$where ($op): ${e.message}${e.invalidValue == null ? '' : ' "${e.invalidValue}"'}',
    );
  }
}

String _source(FormatException e) => e.source == null ? '' : ' "${e.source}"';

TimeBase _timeBase(Map<String, Object?> json, String where) {
  final name = _string(json, 'timeBase', where, optional: true);
  if (name.isEmpty) return TimeBase.second;
  return TimeBase.values.firstWhere(
    (t) => t.name == name,
    orElse: () => throw FormatException('$where: unknown timeBase "$name"'),
  );
}

int _preset(Map<String, Object?> json, String where) {
  final v = json['preset'];
  if (v == null) return 0;
  if (v is! int) throw FormatException('$where: "preset" must be an integer');
  return v;
}

Map<String, Object?> _map(Object? v, String where) {
  if (v is Map<String, Object?>) return v;
  throw FormatException('$where must be an object');
}

List<Object?> _list(Map<String, Object?> json, String key, String where) {
  final v = json[key];
  if (v is List<Object?>) return v;
  throw FormatException('$where: "$key" must be a list');
}

String _string(
  Map<String, Object?> json,
  String key,
  String where, {
  bool optional = false,
}) {
  final v = json[key];
  if (v == null && optional) return '';
  if (v is String) return v;
  throw FormatException('$where: "$key" must be a string');
}

Map<String, String> _stringMap(Map<String, Object?> json, String key) {
  final v = json[key];
  if (v == null) return {};
  if (v is Map<String, Object?> && v.values.every((e) => e is String)) {
    return {for (final e in v.entries) e.key: e.value! as String};
  }
  throw FormatException('"$key" must be an object of strings');
}

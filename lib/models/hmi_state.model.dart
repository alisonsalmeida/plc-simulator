/// Which screen fills the main (left) area of the editor.
enum MainView { ladder, hmi }

/// Kinds of widget the student can place on the Supervisório canvas.
enum HmiKind {
  button('Botão', isBit: true),
  toggle('Chave', isBit: true),
  lamp('Lâmpada', isBit: true),
  display('Display', isBit: false),
  bar('Barra', isBit: false);

  const HmiKind(this.label, {required this.isBit});

  /// Palette name (pt-BR).
  final String label;

  /// True when the widget is bound to a bit address, false for a word address.
  final bool isBit;
}

/// One widget bound to a data table [address] (canonical text, already validated).
class HmiWidget {
  const HmiWidget({
    required this.id,
    required this.kind,
    required this.address,
    required this.label,
    required this.x,
    required this.y,
    this.min = 0,
    this.max = 100,
  });

  final int id;
  final HmiKind kind;
  final String address;
  final String label;
  final double x;
  final double y;

  /// Range of a bar (ignored by the other kinds).
  final int min;
  final int max;

  HmiWidget copyWith({String? address, String? label, double? x, double? y, int? min, int? max}) =>
      HmiWidget(
        id: id,
        kind: kind,
        address: address ?? this.address,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        min: min ?? this.min,
        max: max ?? this.max,
      );
}

class HmiState {
  const HmiState({this.widgets = const [], this.nextId = 1});

  final List<HmiWidget> widgets;
  final int nextId;

  HmiState copyWith({List<HmiWidget>? widgets, int? nextId}) =>
      HmiState(widgets: widgets ?? this.widgets, nextId: nextId ?? this.nextId);
}

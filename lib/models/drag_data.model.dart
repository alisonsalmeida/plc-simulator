/// Payload of every drag in the editor: a toolbar tool, or an element already placed on a rung.
class RungDragData {
  const RungDragData({required this.tool, this.sourceRung, this.sourcePath});

  /// The mnemonic (e.g. 'XIC', 'TON') or tool key (`LadderAssets.branch`, `LadderAssets.rung`).
  final String tool;

  /// Non-null when dragging an already placed element to move it.
  final int? sourceRung;
  final List<int>? sourcePath;

  bool get isMove => sourceRung != null && sourcePath != null;
}

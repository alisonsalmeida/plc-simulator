import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The toolbar tool currently being dragged (null when no drag is in progress).
class DragToolController extends Notifier<String?> {
  @override
  String? build() => null;

  void start(String tool) => state = tool;
  void stop() => state = null;
}

final dragToolProvider = NotifierProvider<DragToolController, String?>(DragToolController.new);

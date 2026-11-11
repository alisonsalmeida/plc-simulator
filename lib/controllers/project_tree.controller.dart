import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/project_tree_state.model.dart';

class ProjectTreeController extends Notifier<ProjectTreeState> {
  @override
  ProjectTreeState build() => const ProjectTreeState();

  void toggle() => state = state.copyWith(isOpen: !state.isOpen);
  void open() => state = state.copyWith(isOpen: true);
  void close() => state = state.copyWith(isOpen: false);
}

final projectTreeProvider =
    NotifierProvider<ProjectTreeController, ProjectTreeState>(
      ProjectTreeController.new,
    );

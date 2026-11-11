import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/hmi_state.model.dart';

/// Chooses between the ladder and the Supervisório in the main area.
class MainViewController extends Notifier<MainView> {
  @override
  MainView build() => MainView.ladder;

  void select(MainView view) => state = view;
}

final mainViewProvider = NotifierProvider<MainViewController, MainView>(MainViewController.new);

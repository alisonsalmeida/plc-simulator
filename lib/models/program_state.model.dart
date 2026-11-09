import 'ladder_example.model.dart';

class ProgramState {
  const ProgramState({required this.examples, this.selected = 0});

  final List<LadderExample> examples;
  final int selected;

  LadderExample get example => examples[selected];

  ProgramState copyWith({int? selected}) =>
      ProgramState(examples: examples, selected: selected ?? this.selected);
}

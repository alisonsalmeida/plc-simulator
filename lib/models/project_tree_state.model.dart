/// UI state of the Project tree panel on the left of the ladder.
class ProjectTreeState {
  const ProjectTreeState({this.isOpen = true, this.width = 220.0});

  final bool isOpen;
  final double width;

  ProjectTreeState copyWith({bool? isOpen, double? width}) => ProjectTreeState(
    isOpen: isOpen ?? this.isOpen,
    width: width ?? this.width,
  );
}

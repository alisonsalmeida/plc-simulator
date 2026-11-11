enum FindMode { find, replace }

/// One occurrence of the query: an instruction in [rung] whose address is [address].
class FindMatch {
  const FindMatch(this.rung, this.address);

  final int rung;
  final String address;
}

/// State of the Localizar / Substituir dialog.
class FindReplaceState {
  const FindReplaceState({
    this.isOpen = false,
    this.mode = FindMode.find,
    this.query = '',
    this.replacement = '',
    this.matchCase = false,
    this.matches = const [],
    this.currentIndex = -1,
  });

  final bool isOpen;
  final FindMode mode;
  final String query;
  final String replacement;
  final bool matchCase;
  final List<FindMatch> matches;

  /// Index into [matches] of the occurrence last shown, or -1 before the first "find next".
  final int currentIndex;

  FindReplaceState copyWith({
    bool? isOpen,
    FindMode? mode,
    String? query,
    String? replacement,
    bool? matchCase,
    List<FindMatch>? matches,
    int? currentIndex,
  }) => FindReplaceState(
    isOpen: isOpen ?? this.isOpen,
    mode: mode ?? this.mode,
    query: query ?? this.query,
    replacement: replacement ?? this.replacement,
    matchCase: matchCase ?? this.matchCase,
    matches: matches ?? this.matches,
    currentIndex: currentIndex ?? this.currentIndex,
  );
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../models/find_replace_state.model.dart';
import 'program.controller.dart';
import 'rung_edit.controller.dart';

/// Finds addresses and symbols across the rungs and replaces symbol text. Addresses are
/// matched but never rewritten: only the symbol attached to an address is replaced.
class FindReplaceController extends Notifier<FindReplaceState> {
  @override
  FindReplaceState build() => const FindReplaceState();

  void openFind() => _open(FindMode.find);
  void openReplace() => _open(FindMode.replace);
  void close() => state = state.copyWith(isOpen: false);

  void setQuery(String query) => _research(state.copyWith(query: query));
  void setMatchCase(bool value) => _research(state.copyWith(matchCase: value));
  void setReplacement(String text) => state = state.copyWith(replacement: text);

  /// Moves to the next occurrence (wrapping) and selects its rung.
  void findNext() {
    final matches = state.matches;
    if (matches.isEmpty) return;
    _goTo((state.currentIndex + 1) % matches.length);
  }

  /// Replaces the symbol text of the current occurrence, then moves to the next one.
  void replaceCurrent() {
    if (state.mode != FindMode.replace) return;
    if (state.currentIndex < 0) return findNext();
    final address = state.matches[state.currentIndex].address;
    final at = state.currentIndex;
    _replaceSymbol(address);
    _research(state);
    final matches = state.matches;
    if (matches.isEmpty) return;
    // A match that survives the replace (matched by address only) is stepped over.
    final stillThere = at < matches.length && matches[at].address == address;
    _goTo(
      stillThere ? (at + 1) % matches.length : at.clamp(0, matches.length - 1),
    );
  }

  /// Replaces the symbol text of every matching address.
  void replaceAll() {
    if (state.mode != FindMode.replace) return;
    for (final address in {for (final m in state.matches) m.address}) {
      _replaceSymbol(address);
    }
    _research(state);
  }

  void _open(FindMode mode) =>
      _research(state.copyWith(isOpen: true, mode: mode));

  void _goTo(int index) {
    state = state.copyWith(currentIndex: index);
    ref.read(programProvider.notifier).selectRung(state.matches[index].rung);
  }

  void _replaceSymbol(String address) {
    final symbol = ref.read(programProvider).program.symbols[address];
    if (symbol == null) return;
    final pattern = RegExp(
      RegExp.escape(state.query),
      caseSensitive: state.matchCase,
    );
    ref
        .read(rungEditProvider.notifier)
        .setSymbol(address, symbol.replaceAll(pattern, state.replacement));
  }

  void _research(FindReplaceState next) {
    state = next.copyWith(matches: _search(next), currentIndex: -1);
  }

  List<FindMatch> _search(FindReplaceState s) {
    if (s.query.isEmpty) return const [];
    final program = ref.read(programProvider).program;
    bool hit(String? text) {
      if (text == null) return false;
      return s.matchCase
          ? text.contains(s.query)
          : text.toLowerCase().contains(s.query.toLowerCase());
    }

    final result = <FindMatch>[];
    void walk(int rung, List<RungElement> series) {
      for (final e in series) {
        switch (e) {
          case Branch():
            for (final path in e.paths) {
              walk(rung, path);
            }
          case Instruction():
            if (hit(e.target) || hit(program.symbols[e.target])) {
              result.add(FindMatch(rung, e.target));
            }
        }
      }
    }

    for (var i = 0; i < program.rungs.length; i++) {
      walk(i, program.rungs[i].elements);
    }
    return result;
  }
}

final findReplaceProvider =
    NotifierProvider<FindReplaceController, FindReplaceState>(
      FindReplaceController.new,
    );

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../../../controllers/runtime.controller.dart';

/// The words of one data file with value equality, so a grid rebuilds only when they change.
@immutable
class FileWords {
  const FileWords(this.words);

  final List<int> words;

  int operator [](int index) => index < words.length ? words[index] : 0;

  @override
  bool operator ==(Object other) => other is FileWords && listEquals(words, other.words);

  @override
  int get hashCode => Object.hashAll(words);
}

final fileWordsProvider = Provider.family<FileWords, BitFile>(
  (ref, file) => FileWords(ref.watch(runtimeProvider.select((s) => s.data[file] ?? const []))),
);

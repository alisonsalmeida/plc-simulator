import 'program.dart';

// Immutable tree edits on a [Rung].
//
// A path addresses a position in the rung: `[i]` is index i of the rung's series;
// `[i, p, j]` is index j of path p inside the [Branch] at index i; deeper branches nest
// further (`[i, p, j, q, k]`, ...). For [insertAt] the last index is a slot (it may equal
// the series length to append).

/// Returns the element at [path].
RungElement elementAt(Rung rung, List<int> path) {
  var series = rung.elements;
  for (var d = 0; d < path.length - 1; d += 2) {
    series = _branchAt(series, path[d]).paths[path[d + 1]];
  }
  return series[path.last];
}

Rung insertAt(Rung rung, List<int> slot, RungElement element) => rung.copyWith(
      elements: _edit(rung.elements, slot, (s, i) => [...s.take(i), element, ...s.skip(i)]),
    );

/// Removes the element at [path]. An emptied branch path is removed too, and a branch left
/// with fewer than two paths is replaced by the contents of its remaining path.
Rung removeAt(Rung rung, List<int> path) => rung.copyWith(elements: _remove(rung.elements, path));

Rung replaceAt(Rung rung, List<int> path, RungElement element) => rung.copyWith(
      elements: _edit(rung.elements, path, (s, i) => [...s.take(i), element, ...s.skip(i + 1)]),
    );

/// Appends a new path holding [first] to the [Branch] at [branchPath].
Rung addBranchPath(Rung rung, List<int> branchPath, RungElement first) => rung.copyWith(
      elements: _edit(rung.elements, branchPath, (s, i) {
        final branch = _branchAt(s, i);
        return [
          ...s.take(i),
          Branch([
            ...branch.paths,
            [first],
          ]),
          ...s.skip(i + 1),
        ];
      }),
    );

Branch _branchAt(List<RungElement> series, int index) {
  final e = series[index];
  if (e is! Branch) throw ArgumentError('Element at index $index is not a branch');
  return e;
}

/// Applies [apply] to the series that [path] ends in, rebuilding the branches on the way.
List<RungElement> _edit(
  List<RungElement> series,
  List<int> path,
  List<RungElement> Function(List<RungElement> series, int index) apply,
) {
  if (path.length == 1) return apply(series, path.first);
  final branch = _branchAt(series, path[0]);
  final paths = [...branch.paths];
  paths[path[1]] = _edit(paths[path[1]], path.sublist(2), apply);
  return [...series.take(path[0]), Branch(paths), ...series.skip(path[0] + 1)];
}

List<RungElement> _remove(List<RungElement> series, List<int> path) {
  if (path.length == 1) return [...series.take(path[0]), ...series.skip(path[0] + 1)];
  final i = path[0];
  final branch = _branchAt(series, i);
  final paths = [...branch.paths];
  final updated = _remove(paths[path[1]], path.sublist(2));
  if (updated.isEmpty && path.length == 3) {
    paths.removeAt(path[1]);
  } else {
    paths[path[1]] = updated;
  }
  final rest = [...series.take(i), ...series.skip(i + 1)];
  if (paths.length >= 2) return [...series.take(i), Branch(paths), ...series.skip(i + 1)];
  return [...series.take(i), ...paths.expand((p) => p), ...rest.skip(i)];
}

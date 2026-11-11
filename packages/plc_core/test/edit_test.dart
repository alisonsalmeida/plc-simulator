import 'package:plc_core/plc_core.dart';
import 'package:test/test.dart';

String show(List<RungElement> s) => s
    .map((e) => switch (e) {
          Instruction() => '${e.mnemonic}(${e.target})',
          Branch(:final paths) => '[${paths.map(show).join(' | ')}]',
        })
    .join(' ');

void main() {
  final start = Xic('I:0/0');
  final seal = Xic('O:0/0');
  final stop = Xio('I:0/1');
  final out = Ote('O:0/0');

  group('Instruction.create / copyWith', () {
    test('creates each mnemonic and rejects unknown ones', () {
      expect(Instruction.create('xic', 'I:0/0'), isA<Xic>());
      expect(Instruction.create('XIO', 'I:0/0'), isA<Xio>());
      expect(Instruction.create('OTE', 'O:0/0'), isA<Ote>());
      expect(Instruction.create('OTL', 'O:0/0'), isA<Otl>());
      expect(Instruction.create('OTU', 'O:0/0'), isA<Otu>());
      expect(() => Instruction.create('FOO', 'B3/0'), throwsArgumentError);
      expect(() => Instruction.create('XIC', 'bad'), throwsFormatException);
    });

    test('copyWith keeps untouched fields', () {
      final rung = Rung([start], comment: 'c');
      expect(rung.copyWith(elements: [out]).comment, 'c');
      expect(rung.copyWith(comment: 'd').elements, [start]);
      final program = Program([rung], symbols: const {'I:0/0': 'S1'});
      expect(program.copyWith(rungs: const []).symbols, {'I:0/0': 'S1'});
      expect(program.copyWith(symbols: const {}).rungs, [rung]);
    });

    test('Rung title defaults to empty and survives copyWith', () {
      expect(const Rung([]).title, '');
      final rung = Rung([start], comment: 'c', title: 'T');
      expect(rung.copyWith(elements: [out]).title, 'T');
      expect(rung.copyWith(title: 'U').title, 'U');
      expect(rung.copyWith(title: 'U').comment, 'c');
    });

    test('Program descriptions: lookup by address and copyWith', () {
      final program = Program(
        [Rung([start])],
        symbols: const {'I:0/0': 'S1'},
        descriptions: const {'I:0/0': 'Botão liga\nmotor M1'},
      );
      expect(program.descriptionFor(BitAddress.parse('I:0/0')), 'Botão liga\nmotor M1');
      expect(program.descriptionFor(BitAddress.parse('I:0/1')), isNull);
      expect(Program(const []).descriptions, isEmpty);
      expect(program.copyWith(rungs: const []).descriptions, hasLength(1));
      expect(program.copyWith(descriptions: const {}).symbols, {'I:0/0': 'S1'});
    });
  });

  group('insertAt', () {
    test('inserts and appends in the main series without mutating the original', () {
      final rung = Rung([start, out], comment: 'x');
      final r = insertAt(rung, [1], stop);
      expect(show(r.elements), 'XIC(I:0/0) XIO(I:0/1) OTE(O:0/0)');
      expect(show(insertAt(rung, [2], stop).elements), 'XIC(I:0/0) OTE(O:0/0) XIO(I:0/1)');
      expect(show(rung.elements), 'XIC(I:0/0) OTE(O:0/0)');
      expect(r.comment, 'x');
    });

    test('inserts into an empty rung and into nested branch paths', () {
      expect(show(insertAt(const Rung([]), [0], start).elements), 'XIC(I:0/0)');
      final rung = Rung([
        Branch([
          [start],
          [
            Branch([[], []]),
          ],
        ]),
      ]);
      final r = insertAt(rung, [0, 1, 0, 1, 0], seal);
      expect(show(r.elements), '[XIC(I:0/0) | [ | XIC(O:0/0)]]');
      expect(show(insertAt(rung, [0, 0, 1], stop).elements), startsWith('[XIC(I:0/0) XIO(I:0/1) |'));
    });
  });

  group('replaceAt / elementAt', () {
    test('replaces top-level and nested elements', () {
      final rung = Rung([
        Branch([
          [start],
          [seal],
        ]),
        out,
      ]);
      expect(elementAt(rung, [0, 1, 0]), same(seal));
      expect(show(replaceAt(rung, [1], Otl('O:0/0')).elements), '[XIC(I:0/0) | XIC(O:0/0)] OTL(O:0/0)');
      expect(show(replaceAt(rung, [0, 1, 0], stop).elements), '[XIC(I:0/0) | XIO(I:0/1)] OTE(O:0/0)');
    });
  });

  group('addBranchPath', () {
    test('appends a path to a top-level and a nested branch', () {
      final rung = Rung([
        Branch([
          [start],
          [
            Branch([
              [seal],
              [],
            ]),
          ],
        ]),
      ]);
      expect(show(addBranchPath(rung, [0], stop).elements),
          '[XIC(I:0/0) | [XIC(O:0/0) | ] | XIO(I:0/1)]');
      expect(show(addBranchPath(rung, [0, 1, 0], stop).elements),
          '[XIC(I:0/0) | [XIC(O:0/0) |  | XIO(I:0/1)]]');
    });

    test('rejects a path that is not a branch', () {
      expect(() => addBranchPath(Rung([start]), [0], stop), throwsArgumentError);
    });
  });

  group('removeAt', () {
    test('removes a top-level element', () {
      expect(show(removeAt(Rung([start, stop, out]), [1]).elements), 'XIC(I:0/0) OTE(O:0/0)');
    });

    test('removing from a path with siblings keeps the path', () {
      final rung = Rung([
        Branch([
          [start, stop],
          [seal],
        ]),
      ]);
      expect(show(removeAt(rung, [0, 0, 1]).elements), '[XIC(I:0/0) | XIC(O:0/0)]');
    });

    test('removing the last element of a path removes the path; a 3-path branch stays a branch', () {
      final rung = Rung([
        Branch([
          [start],
          [seal],
          [stop],
        ]),
      ]);
      expect(show(removeAt(rung, [0, 1, 0]).elements), '[XIC(I:0/0) | XIO(I:0/1)]');
    });

    test('a branch left with one path collapses into the parent series', () {
      final rung = Rung([
        Branch([
          [start, stop],
          [seal],
        ]),
        out,
      ]);
      expect(show(removeAt(rung, [0, 1, 0]).elements), 'XIC(I:0/0) XIO(I:0/1) OTE(O:0/0)');
    });

    test('collapse of a nested branch flattens into the enclosing path', () {
      final rung = Rung([
        Branch([
          [
            Branch([
              [start],
              [seal],
            ]),
            stop,
          ],
          [out],
        ]),
      ]);
      final r = removeAt(rung, [0, 0, 0, 1, 0]);
      expect(show(r.elements), '[XIC(I:0/0) XIO(I:0/1) | OTE(O:0/0)]');
    });

    test('removing the only content of a collapsing branch makes it vanish', () {
      final rung = Rung([
        Branch([
          [start],
          [],
        ]),
        out,
      ]);
      expect(show(removeAt(rung, [0, 0, 0]).elements), 'OTE(O:0/0)');
    });
  });

  test('a branch of empty paths acts as a wire', () {
    final engine = ScanEngine(Program([
      Rung([
        Xic('I:0/0'),
        Branch([[], []]),
        Ote('O:0/0'),
      ]),
    ]));
    engine.inputImage = 1;
    final trace = engine.scan();
    expect(trace.rungs.single, [true, true]);
    expect(engine.outputImage, 1);
    engine.inputImage = 0;
    engine.scan();
    expect(engine.outputImage, 0);
  });
}

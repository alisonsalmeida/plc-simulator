import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/element_edit.controller.dart';
import 'package:plc_simulator/controllers/find_replace.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/rung_edit.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/models/find_replace_state.model.dart';

void main() {
  late ProviderContainer container;

  FindReplaceController find() => container.read(findReplaceProvider.notifier);
  FindReplaceState state() => container.read(findReplaceProvider);
  Map<String, String> symbols() =>
      container.read(programProvider).program.symbols;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(ladderExamples.length - 1);
    final rungs = container.read(rungEditProvider.notifier);
    final edit = container.read(elementEditProvider.notifier);
    rungs.addRung();
    rungs.addRung();
    edit.insertElement(
      0,
      [0],
      Branch([
        [Instruction.create('XIC', 'I:0/0')],
        [Instruction.create('XIC', 'O:0/0')],
      ]),
    );
    edit.insertElement(0, [1], Instruction.create('OTE', 'O:0/0'));
    edit.insertElement(1, [0], Instruction.create('XIC', 'I:0/1'));
    rungs.setSymbol('I:0/0', 'Botao Liga');
    rungs.setSymbol('O:0/0', 'Motor');
    rungs.setSymbol('I:0/1', 'Botao Desliga');
  });

  test('openFind and openReplace set the mode; close hides', () {
    find().openFind();
    expect(state().isOpen, isTrue);
    expect(state().mode, FindMode.find);
    find().openReplace();
    expect(state().mode, FindMode.replace);
    find().close();
    expect(state().isOpen, isFalse);
  });

  test(
    'matches symbols and addresses across rungs and branches, honouring match case',
    () {
      find().setQuery('botao');
      expect(state().matches.map((m) => m.rung), [0, 1]);
      find().setMatchCase(true);
      expect(state().matches, isEmpty);
      find().setMatchCase(false);
      find().setQuery('o:0/0');
      expect(state().matches.length, 2); // the branch contact and the coil
    },
  );

  test('findNext cycles through the matches and selects their rung', () {
    find().setQuery('botao');
    find().findNext();
    expect(state().currentIndex, 0);
    expect(container.read(programProvider).selectedRung, 0);
    find().findNext();
    expect(container.read(programProvider).selectedRung, 1);
    find().findNext();
    expect(state().currentIndex, 0);
  });

  test('replaceCurrent and replaceAll rewrite symbol text only', () {
    find().openReplace();
    find().setQuery('Botao');
    find().setReplacement('Btn');
    find().findNext();
    find().replaceCurrent();
    expect(symbols()['I:0/0'], 'Btn Liga');
    expect(symbols()['I:0/1'], 'Botao Desliga');
    find().replaceAll();
    expect(symbols()['I:0/1'], 'Btn Desliga');
    expect(state().matches, isEmpty);
  });

  test('replace does nothing in find mode', () {
    find().openFind();
    find().setQuery('Botao');
    find().setReplacement('Btn');
    find().replaceAll();
    expect(symbols()['I:0/0'], 'Botao Liga');
  });
}

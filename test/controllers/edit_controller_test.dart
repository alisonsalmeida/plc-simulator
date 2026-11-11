import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/element_edit.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/rung_edit.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(ladderExamples.length - 1);
  });

  Program program() => container.read(programProvider).program;

  test('"Novo programa" starts with no rungs', () {
    expect(program().rungs, isEmpty);
  });

  test('builds a seal-in start/stop circuit that latches and drops', () async {
    final elements = container.read(elementEditProvider.notifier);
    final rungs = container.read(rungEditProvider.notifier);
    rungs.addRung();
    elements.insertElement(0, [0], const Branch([[], []]));
    elements.insertElement(0, [0, 0, 0], Instruction.create('XIC', 'I:0/0'));
    elements.insertElement(0, [0, 1, 0], Instruction.create('XIC', 'O:0/0'));
    elements.insertElement(0, [1], Instruction.create('XIO', 'I:0/1'));
    elements.insertElement(0, [2], Instruction.create('OTE', 'O:0/0'));
    rungs.setSymbol('O:0/0', 'K1 Motor');
    rungs.setComment(0, 'Partida com selo');
    expect(program().symbolFor(BitAddress.parse('O:0/0')), 'K1 Motor');
    expect(program().rungs.single.comment, 'Partida com selo');

    final runtime = container.read(runtimeProvider.notifier);
    runtime.setInput(0, true);
    runtime.step();
    runtime.setInput(0, false);
    runtime.step();
    await settle();
    expect(container.read(runtimeProvider).output(0), isTrue);

    runtime.setInput(1, true);
    runtime.step();
    await settle();
    expect(container.read(runtimeProvider).output(0), isFalse);
  });

  test('update, delete, add path, rungs and symbols', () {
    final elements = container.read(elementEditProvider.notifier);
    final rungs = container.read(rungEditProvider.notifier);
    rungs.addRung();
    elements.insertElement(0, [0], Instruction.create('XIC', 'I:0/0'));
    elements.updateInstruction(0, [0], 'I:0/5');
    expect((program().rungs[0].elements[0] as Xic).address.toString(), 'I:0/5');

    elements.insertElement(0, [1], const Branch([[], []]));
    elements.addPath(0, [1], Instruction.create('XIC', 'I:0/2'));
    expect((program().rungs[0].elements[1] as Branch).paths, hasLength(3));
    elements.deleteElement(0, [1, 2, 0]);
    expect((program().rungs[0].elements[1] as Branch).paths, hasLength(2));

    rungs.addRung();
    expect(program().rungs, hasLength(2));
    rungs.deleteRung(0);
    expect(program().rungs, hasLength(1));

    rungs.setSymbol('I:0/0', 'S1');
    rungs.setSymbol('I:0/0', '');
    expect(program().symbols.containsKey('I:0/0'), isFalse);
  });

  test('rung selection, add after selected and delete selected', () {
    final rungs = container.read(rungEditProvider.notifier);
    rungs.addRung();
    rungs.addRung();
    rungs.setTitle(0, 'first');
    rungs.setTitle(1, 'second');
    expect(container.read(programProvider).selectedRung, 1);
    container.read(programProvider.notifier).selectRung(0);
    rungs.addRung();
    expect(program().rungs, hasLength(3));
    expect(container.read(programProvider).selectedRung, 1);
    expect(program().rungs[2].title, 'second');
    rungs.deleteSelectedRung();
    expect(program().rungs.map((r) => r.title), ['first', 'second']);
    expect(container.read(programProvider).selectedRung, isNull);
    rungs.deleteSelectedRung();
    expect(program().rungs, hasLength(2));
  });

  test('descriptions are stored per address and cleared when empty', () {
    final rungs = container.read(rungEditProvider.notifier);
    rungs.setDescription('I:0/0', 'Botão\nliga');
    expect(program().descriptionFor(BitAddress.parse('I:0/0')), 'Botão\nliga');
    rungs.setDescription('I:0/0', '');
    expect(program().descriptionFor(BitAddress.parse('I:0/0')), isNull);
  });

  test('selecting an example loads a fresh program', () {
    container.read(programProvider.notifier).select(0);
    final original = program();
    container.read(elementEditProvider.notifier).deleteElement(0, [1]);
    expect(program().rungs[0].elements.length, lessThan(original.rungs[0].elements.length));
    container.read(programProvider.notifier).select(0);
    expect(program().rungs[0].elements.length, original.rungs[0].elements.length);
  });
}

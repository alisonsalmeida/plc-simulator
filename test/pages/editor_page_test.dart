import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/element_edit.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/rung_edit.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets('editor shows the toolbar tabs, END and an example rung', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: EditorPage())));
    await tester.pump();
    for (final label in ['User', 'Bit', 'Timer/Counter', 'Input/Output', 'Compare']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('END'), findsOneWidget);
    expect(find.text('0000'), findsOneWidget);
    expect(find.text('PARTIDA DIRETA'), findsOneWidget);
    expect(find.textContaining('Botão liga'), findsWidgets);
    expect(find.text('+ caminho'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new program with an empty branch lays out without errors', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(ladderExamples.length - 1);
    container.read(rungEditProvider.notifier).addRung();
    final edit = container.read(elementEditProvider.notifier);
    edit.insertElement(0, [0], const Branch([[], []]));
    edit.insertElement(0, [0, 0, 0], Instruction.create('XIC', 'I:0/0'));
    edit.insertElement(0, [1], Instruction.create('OTE', 'O:0/0'));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: EditorPage())),
    );
    await tester.pump();
    expect(find.text('I:0/0'), findsWidgets);
    expect(find.text('O:0/0'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

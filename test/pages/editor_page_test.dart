import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/element_edit.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/rung_edit.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets('editor shows the toolbar tabs, END and an example rung', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: EditorPage())));
    await tester.pump();
    for (final label in ['User', 'Bit', 'Timer/Counter', 'Input/Output', 'Compare', 'Move/Logical']) {
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

  testWidgets('Timer/Counter tab offers the new tools and the TON example draws its box', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(ladderExamples.indexWhere((e) => e.name.contains('TON')));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: EditorPage())),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Timer On Delay'), findsOneWidget);
    for (final text in ['Timer', 'Time Base', 'Preset', 'Accum', '(EN)', '(DN)']) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
    expect(find.byTooltip('TON – Temporizador na energização'), findsNothing);
    await tester.tap(find.text('Timer/Counter'));
    await tester.pump();
    for (final tip in [
      'TON – Temporizador na energização',
      'TOF – Temporizador na desenergização',
      'RTO – Temporizador retentivo',
      'CTU – Contador crescente',
      'CTD – Contador decrescente',
      'RES – Reset',
    ]) {
      expect(find.byTooltip(tip), findsOneWidget, reason: tip);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('timer dialog validates address and preset', (tester) async {
    InstructionInput? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showInstructionDialog(context, mnemonic: 'TON'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'C5:0');
    await tester.enterText(fields.at(1), '40000');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Endereço inválido'), findsOneWidget);
    expect(find.text('Preset inválido (0 a 32767)'), findsOneWidget);
    await tester.enterText(fields.at(0), 't4:2');
    await tester.enterText(fields.at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result?.address, 'T4:2');
    expect(result?.preset, 30);
    expect(result?.timeBase, TimeBase.second);
  });
}

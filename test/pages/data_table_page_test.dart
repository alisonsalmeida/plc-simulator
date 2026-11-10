import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/data_table/data_table_window.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/components/pane_splitter.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

Future<ProviderContainer> pumpEditor(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(programProvider.notifier).select(ladderExamples.indexWhere((e) => e.name.contains('MOV')));
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MaterialApp(home: EditorPage())),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('Move/Logical tab offers BRANCH, MOV, MVM and CLR; MOV box renders', (tester) async {
    await pumpEditor(tester);
    expect(find.text('Move'), findsOneWidget);
    expect(find.text('Source'), findsWidgets);
    expect(find.text('N7:0'), findsWidgets);
    await tester.tap(find.text('Move/Logical'));
    await tester.pump();
    for (final tip in [find.byTooltip(RegExp('^MOV')), find.byTooltip(RegExp('^MVM')), find.byTooltip(RegExp('^CLR'))]) {
      expect(tip, findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Data Files window lists N7, edits a word and toggles a B3 bit', (tester) async {
    final container = await pumpEditor(tester);
    await tester.tap(find.text('Data Files'));
    await tester.pump();
    expect(find.byKey(const ValueKey('file-N7')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('file-N7')));
    await tester.pump();
    for (final row in ['N7:0', 'N7:10', 'N7:20', 'N7:30']) {
      expect(find.text(row), findsWidgets, reason: row);
    }

    await tester.tap(find.byKey(const ValueKey('cell-N7:3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1234');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:3')), 1234);

    await tester.tap(find.byKey(const ValueKey('file-B3')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bit-B3:0/3')));
    await tester.pump();
    expect(container.read(runtimeProvider).bit(BitAddress.parse('B3:0/3')), isTrue);

    await tester.tap(find.byKey(const ValueKey('file-O')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('bit-O:0/0')));
    await tester.pump();
    expect(container.read(runtimeProvider).bit(BitAddress.parse('O:0/0')), isFalse);
    await tester.tap(find.byKey(const ValueKey('data-close')));
    await tester.pump();
    expect(find.byKey(const ValueKey('file-N7')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging the splitter up grows the Data Files pane', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.text('Data Files'));
    await tester.pump();
    final before = tester.getSize(find.byType(DataTableWindow)).height;
    await tester.drag(find.byType(PaneSplitter), const Offset(0, -100));
    await tester.pump();
    expect(tester.getSize(find.byType(DataTableWindow)).height, greaterThan(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets('MOV dialog validates source and destination', (tester) async {
    InstructionInput? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showInstructionDialog(context, mnemonic: 'MOV'),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'zz');
    await tester.enterText(fields.at(1), 'N9:0');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Endereço ou valor inválido'), findsOneWidget);
    expect(find.text('Endereço inválido'), findsOneWidget);
    await tester.enterText(fields.at(0), '100');
    await tester.enterText(fields.at(1), 'n7:5');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result?.source, '100');
    expect(result?.address, 'N7:5');
  });
}

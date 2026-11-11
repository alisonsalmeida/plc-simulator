import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/data_table.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/pages/data_table/data_table_window.dart';
import 'package:plc_simulator/pages/editor/components/box_cell.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/components/project_tree.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

Future<void> openDialog(
  WidgetTester tester,
  String mnemonic,
  void Function(InstructionInput?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => onResult(
            await showInstructionDialog(context, mnemonic: mnemonic),
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('toolbar tabs offer ONS, MOD, XPY and SWP', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    container.read(projectTreeProvider.notifier).close();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorPage()),
      ),
    );
    await tester.pump();
    expect(find.byTooltip(RegExp('^ONS')), findsOneWidget);
    await tester.tap(find.text('Compute/Math'));
    await tester.pump();
    expect(find.byTooltip(RegExp('^MOD')), findsOneWidget);
    expect(find.byTooltip(RegExp('^XPY')), findsOneWidget);
    await tester.tap(find.text('Move/Logical'));
    await tester.pump();
    expect(find.byTooltip(RegExp('^SWP')), findsOneWidget);
  });

  testWidgets('MOD and XPY dialogs take A, B and a float destination', (
    tester,
  ) async {
    for (final m in ['MOD', 'XPY']) {
      InstructionInput? result;
      await openDialog(tester, m, (r) => result = r);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'f8:0');
      await tester.enterText(fields.at(1), '2.5');
      await tester.enterText(fields.at(2), 'F8:1');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result?.source, 'F8:0', reason: m);
      expect(result?.mask, '2.5', reason: m);
      expect(result?.address, 'F8:1', reason: m);
    }
  });

  testWidgets('SWP and ONS dialogs', (tester) async {
    InstructionInput? result;
    await openDialog(tester, 'SWP', (r) => result = r);
    await tester.enterText(find.byType(TextField).at(0), 'N7:0');
    await tester.enterText(find.byType(TextField).at(1), 'N7:1');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((result?.source, result?.address), ('N7:0', 'N7:1'));

    await openDialog(tester, 'ONS', (r) => result = r);
    await tester.enterText(find.byType(TextField).at(0), 'B3:0/1');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result?.address, 'B3:0/1');
  });

  test('box titles', () {
    expect(
      BoxCell.titleOf(
        Instruction.create('MOD', 'N7:0', source: '1', mask: '1'),
      ),
      'Modulo',
    );
    expect(
      BoxCell.titleOf(
        Instruction.create('XPY', 'N7:0', source: '1', mask: '1'),
      ),
      'Exponentiation',
    );
    expect(
      BoxCell.titleOf(Instruction.create('SWP', 'N7:0', source: '1')),
      'Swap',
    );
  });

  testWidgets(
    'project tree F8 opens the float Data File, which edits a float',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  ProjectTree(),
                  Expanded(child: DataTableWindow()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('F8 - FLOAT').first);
      await tester.pump();
      expect(container.read(dataTableProvider).file, BitFile.float);
      for (final row in ['F8:0', 'F8:10']) {
        expect(find.text(row), findsWidgets, reason: row);
      }
      await tester.tap(find.byKey(const ValueKey('cell-F8:3')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '12.5');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        container.read(runtimeProvider).float(WordAddress.parse('F8:3')),
        12.5,
      );
      expect(find.text('12.5'), findsWidgets);
    },
  );

  test('MOD runs online through the runtime', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final runtime = container.read(runtimeProvider.notifier);
    container
        .read(runtimeServiceProvider)
        .load(
          Program([
            Rung([Instruction.create('MOD', 'N7:2', source: '17', mask: '5')]),
          ]),
        );
    runtime.step();
    await Future<void>.delayed(Duration.zero);
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:2')), 2);
  });
}

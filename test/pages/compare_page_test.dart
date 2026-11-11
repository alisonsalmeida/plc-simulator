import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets(
    'Compare tab lists the seven instructions; the example draws its boxes',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      container.read(projectTreeProvider.notifier).close();
      addTearDown(container.dispose);
      container
          .read(programProvider.notifier)
          .select(
            ladderExamples.indexWhere((e) => e.name.contains('GRT/LES/LIM')),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorPage()),
        ),
      );
      await tester.pump();
      expect(find.text('Greater Than'), findsOneWidget);
      expect(find.text('Limit Test'), findsOneWidget);
      expect(find.text('Source A'), findsWidgets);
      expect(find.text('Low Lim'), findsOneWidget);
      await tester.tap(find.text('Compare'));
      await tester.pump();
      for (final m in ['EQU', 'NEQ', 'LES', 'LEQ', 'GRT', 'GEQ', 'LIM']) {
        expect(find.byTooltip(RegExp('^$m')), findsOneWidget, reason: m);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'EQU dialog accepts a constant for Source B and rejects a constant Source A',
    (tester) async {
      InstructionInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showInstructionDialog(
                context,
                mnemonic: 'EQU',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '5');
      await tester.enterText(fields.at(1), '10');
      await tester.tap(find.text('OK'));
      await tester.pump();
      expect(find.text('Endereço inválido'), findsOneWidget);
      await tester.enterText(fields.at(0), 'n7:2');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result?.address, 'N7:2');
      expect(result?.source, '10');
      final ins = Instruction.create(
        'EQU',
        result!.address,
        source: result!.source,
      );
      expect(ins, isA<Equ>());
    },
  );

  testWidgets(
    'LIM dialog takes constants or addresses for low, test and high',
    (tester) async {
      InstructionInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showInstructionDialog(
                context,
                mnemonic: 'LIM',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '20');
      await tester.enterText(fields.at(1), 'n7:0');
      await tester.enterText(fields.at(2), 'N7:1');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(
        (result?.source, result?.address, result?.mask),
        ('20', 'N7:0', 'N7:1'),
      );
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets(
    'Shift/FIFO tab lists the six instructions; the example draws FFL and FFU boxes',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      container.read(projectTreeProvider.notifier).close();
      addTearDown(container.dispose);
      container
          .read(programProvider.notifier)
          .select(ladderExamples.indexWhere((e) => e.name.contains('FFL')));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: EditorPage()),
        ),
      );
      await tester.pump();
      expect(find.text('FIFO Load'), findsOneWidget);
      expect(find.text('FIFO Unload'), findsOneWidget);
      await tester.tap(find.text('Shift/FIFO'));
      await tester.pump();
      for (final m in ['BSL', 'BSR', 'FFL', 'FFU', 'LFL', 'LFU']) {
        expect(find.byTooltip(RegExp('^$m')), findsOneWidget, reason: m);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('FFL dialog collects source, control, array and length', (
    tester,
  ) async {
    InstructionInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showInstructionDialog(context, mnemonic: 'FFL'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'N7:0');
    await tester.enterText(fields.at(1), 'R6:0');
    await tester.enterText(fields.at(2), 'N7:10');
    await tester.enterText(fields.at(3), '0');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Comprimento inválido (1 a 128)'), findsOneWidget);
    await tester.enterText(fields.at(3), '8');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      (result?.address, result?.source, result?.mask, result?.preset),
      ('N7:10', 'N7:0', 'R6:0', 8),
    );
    expect(
      Instruction.create(
        'FFL',
        result!.address,
        source: result!.source,
        mask: result!.mask,
        preset: result!.preset,
      ),
      isA<Ffl>(),
    );
  });
}

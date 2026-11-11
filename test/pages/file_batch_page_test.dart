import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets('File/Misc tab lists COP, FLL, AVE and SRT; the boxes are drawn', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    container.read(projectTreeProvider.notifier).close();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).loadProgram(
          Program([
            for (final i in [
              Instruction.create('COP', 'N7:10', source: '#N7:0', preset: 4),
              Instruction.create('FLL', 'N7:20', source: '5', preset: 2),
              Instruction.create('AVE', 'N7:0', source: 'N7:30', offset: 'R6:0', preset: 3),
              Instruction.create('SRT', 'N7:0', offset: 'R6:1', preset: 3),
            ])
              Rung([Instruction.create('XIC', 'I:0/0'), i]),
          ]),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: EditorPage())),
    );
    await tester.pump();
    for (final t in ['Copy File', 'File Fill', 'File Average', 'File Sort']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    await tester.ensureVisible(find.text('File/Misc'));
    await tester.pump();
    await tester.tap(find.text('File/Misc'));
    await tester.pump();
    for (final m in ['COP', 'FLL', 'AVE', 'SRT']) {
      expect(find.byTooltip(RegExp('^$m')), findsOneWidget, reason: m);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('COP dialog collects source, destination and length', (tester) async {
    InstructionInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showInstructionDialog(context, mnemonic: 'COP'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '#N7:0');
    await tester.enterText(fields.at(1), '#N7:10');
    await tester.enterText(fields.at(2), '200');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Comprimento inválido (1 a 128)'), findsOneWidget);
    await tester.enterText(fields.at(2), '4');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((result?.address, result?.source, result?.preset), ('N7:10', '#N7:0', 4));
    expect(
      Instruction.create('COP', result!.address, source: result!.source, preset: result!.preset),
      isA<Cop>(),
    );
  });

  testWidgets('AVE dialog collects file, destination, control and length', (tester) async {
    InstructionInput? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showInstructionDialog(context, mnemonic: 'AVE'),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'N7:9');
    await tester.enterText(fields.at(1), 'R6:0');
    await tester.enterText(fields.at(2), 'N7:0');
    await tester.enterText(fields.at(3), '3');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      (result?.address, result?.source, result?.offset, result?.preset),
      ('N7:0', 'N7:9', 'R6:0', 3),
    );
  });
}

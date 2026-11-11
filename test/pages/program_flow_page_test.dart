import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void main() {
  testWidgets('Program Flow tab lists the seven instructions', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    container.read(projectTreeProvider.notifier).close();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).replaceProgram(
      Program([
        Rung([Xic('I:0/0'), Jsr(3), Jmp(1)]),
      ]),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: EditorPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Subroutine'), findsOneWidget);
    await tester.ensureVisible(find.text('Program Flow'));
    await tester.pump();
    await tester.tap(find.text('Program Flow'));
    await tester.pump();
    for (final m in ['JSR', 'SBR', 'RET', 'JMP', 'LBL', 'MCR', 'TND']) {
      expect(find.byTooltip(RegExp('^$m')), findsOneWidget, reason: m);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('JMP dialog asks for a label; MCR has no operands', (tester) async {
    InstructionInput? result;
    String mnemonic = 'JMP';
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showInstructionDialog(context, mnemonic: mnemonic),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Q2:5');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result?.address, 'Q2:5');
    expect(Instruction.create('JMP', result!.address), isA<Jmp>());

    mnemonic = 'MCR';
    result = null;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Esta instrução não tem operandos.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result?.address, 'MCR');
  });

  testWidgets('adding a subroutine switches the edited routine', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(programProvider.notifier);
    c.addSubroutine();
    var s = container.read(programProvider);
    expect(s.activeRoutine, 3);
    expect(s.rungs.single.elements.single, isA<Sbr>());
    c.setActiveRoutine(2);
    expect(container.read(programProvider).activeRoutine, 2);
  });
}

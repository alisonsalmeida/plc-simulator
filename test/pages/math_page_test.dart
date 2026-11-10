import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

Future<void> openDialog(WidgetTester tester, String mnemonic, void Function(InstructionInput?) onResult) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => TextButton(
        onPressed: () async => onResult(await showInstructionDialog(context, mnemonic: mnemonic)),
        child: const Text('open'),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Compute/Math tab lists the seven instructions; the example draws its boxes', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(programProvider.notifier)
        .select(ladderExamples.indexWhere((e) => e.name.contains('SCL/ADD/DIV')));
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: EditorPage())),
    );
    await tester.pump();
    expect(find.text('Scale'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Divide'), findsOneWidget);
    expect(find.text('Rate [/10000]'), findsOneWidget);
    await tester.tap(find.text('Compute/Math'));
    await tester.pump();
    for (final m in ['ADD', 'SUB', 'MUL', 'DIV', 'NEG', 'SQR', 'SCL']) {
      expect(find.byTooltip(RegExp('^$m')), findsOneWidget, reason: m);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('ADD dialog accepts a constant for Source B and requires a word destination', (tester) async {
    InstructionInput? result;
    await openDialog(tester, 'ADD', (r) => result = r);
    expect(find.text('Origem A'), findsOneWidget);
    expect(find.text('Origem B'), findsOneWidget);
    expect(find.text('Destino'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'n7:0');
    await tester.enterText(fields.at(1), '10');
    await tester.enterText(fields.at(2), '5');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.text('Endereço inválido'), findsOneWidget);
    await tester.enterText(fields.at(2), 'n7:2');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((result?.source, result?.mask, result?.address), ('N7:0', '10', 'N7:2'));
    final ins = Instruction.create('ADD', result!.address, source: result!.source, mask: result!.mask);
    expect(ins, isA<Add>());
    expect((ins as Add).sourceB, const Constant(10));
  });

  testWidgets('SCL dialog asks source, rate, offset and destination', (tester) async {
    InstructionInput? result;
    await openDialog(tester, 'SCL', (r) => result = r);
    expect(find.text('Taxa [/10000]'), findsOneWidget);
    expect(find.text('Deslocamento'), findsOneWidget);
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'N7:0');
    await tester.enterText(fields.at(1), '610');
    await tester.enterText(fields.at(2), '-3');
    await tester.enterText(fields.at(3), 'N7:1');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect((result?.source, result?.mask, result?.offset, result?.address), ('N7:0', '610', '-3', 'N7:1'));
    expect(
      Instruction.create('SCL', result!.address, source: result!.source, mask: result!.mask, offset: result!.offset),
      isA<Scl>(),
    );
  });
}

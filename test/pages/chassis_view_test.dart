import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/io_panel.controller.dart';
import 'package:plc_simulator/controllers/main_view.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/models/hmi_state.model.dart';
import 'package:plc_simulator/pages/editor/components/instruction_dialog.dart';
import 'package:plc_simulator/pages/editor/components/io_panel.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

void bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'chassis view shows the rack, selects a slot and installs a module',
    (tester) async {
      bigScreen(tester);
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: EditorPage()),
        ),
      );
      c.read(mainViewProvider.notifier).select(MainView.chassis);
      await tester.pump();
      expect(find.text('Visão de Montagem do CLP'), findsOneWidget);
      expect(find.byKey(const ValueKey('chassis-rack')), findsOneWidget);
      for (var s = 0; s < 10; s++) {
        expect(find.byKey(ValueKey('chassis-slot-$s')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('chassis-slot-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chassis-module-1746-OB16')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Instalar no Slot [1]'));
      await tester.pump();
      expect(
        c.read(programProvider).program.chassis.moduleAt(1),
        ModuleCatalog.ob16,
      );
      await tester.tap(find.text('Remover do Slot [1]'));
      await tester.pump();
      expect(
        c.read(programProvider).program.chassis.moduleAt(1),
        ModuleCatalog.empty,
      );
    },
  );

  testWidgets(
    'instruction dialog rejects an address the chassis does not have',
    (tester) async {
      final chassis = ChassisConfig.defaultConfig().setSlot(
        1,
        ModuleCatalog.ob16,
      );
      InstructionInput? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showInstructionDialog(
                context,
                mnemonic: 'XIC',
                chassis: chassis,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'I:1/0');
      await tester.pump();
      expect(find.textContaining('1746-OB16'), findsOneWidget);
      final ok = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'OK'),
      );
      expect(ok.onPressed, isNull);
      await tester.enterText(find.byType(TextField).first, 'O:1/0');
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result?.address, 'O:1/0');
    },
  );

  testWidgets('io panel follows the configured slots', (tester) async {
    tester.view.physicalSize = const Size(600, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(runtimeProvider);
    c.read(ioPanelTabProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: Scaffold(body: IoPanel())),
      ),
    );
    expect(find.text('Entradas (I:0)'), findsOneWidget);
    expect(find.text('Saídas Slot 1 (O:1)'), findsNothing);
    c.read(programProvider.notifier).setChassisSlot(1, ModuleCatalog.ob16);
    await tester.pump();
    expect(find.text('Saídas Slot 1 (O:1)'), findsOneWidget);
    expect(find.text('Entradas Slot 1 (I:1)'), findsNothing);
    c.read(programProvider.notifier).setChassisSlot(1, ModuleCatalog.ib16);
    await tester.pump();
    expect(find.text('Entradas Slot 1 (I:1)'), findsOneWidget);
  });
}

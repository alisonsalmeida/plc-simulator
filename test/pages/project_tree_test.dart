import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/data_table.controller.dart';
import 'package:plc_simulator/controllers/main_view.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/models/hmi_state.model.dart';
import 'package:plc_simulator/pages/editor/components/project_tree.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Row(children: [ProjectTree()])),
        ),
      ),
    );
  }

  test('controller toggles, opens and closes', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(projectTreeProvider).isOpen, isTrue);
    expect(c.read(projectTreeProvider).width, 220.0);
    c.read(projectTreeProvider.notifier).toggle();
    expect(c.read(projectTreeProvider).isOpen, isFalse);
    c.read(projectTreeProvider.notifier).open();
    expect(c.read(projectTreeProvider).isOpen, isTrue);
    c.read(projectTreeProvider.notifier).close();
    expect(c.read(projectTreeProvider).isOpen, isFalse);
  });

  testWidgets(
    'data file nodes select the file and open the Data Files window',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('B3 - BINARY'));
      await tester.pump();
      expect(container.read(dataTableProvider).file, BitFile.bit);
      expect(container.read(dataTableProvider).open, isTrue);
      await tester.tap(find.text('Status do Processador'));
      await tester.pump();
      expect(container.read(dataTableProvider).file, BitFile.status);
    },
  );

  testWidgets('program and supervisory nodes switch the main view', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('IHM - Telas'));
    expect(container.read(mainViewProvider), MainView.hmi);
    await tester.tap(find.text('LAD 2 - MAIN'));
    expect(container.read(mainViewProvider), MainView.ladder);
  });

  testWidgets(
    'controller dialogs open, folders collapse and the close button hides the tree',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Propriedades do Controlador'));
      await tester.pumpAndSettle();
      expect(find.textContaining('MicroLogix 1400 Emulado'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configuração de E/S'));
      await tester.pump();
      expect(container.read(mainViewProvider), MainView.chassis);

      await tester.tap(find.text('Arquivos de Dados'));
      await tester.pump();
      expect(find.text('N7 - INTEGER'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('tree-close')));
      expect(container.read(projectTreeProvider).isOpen, isFalse);
    },
  );
}

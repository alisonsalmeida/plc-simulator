import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/data_table.controller.dart';
import 'package:plc_simulator/controllers/find_replace.controller.dart';
import 'package:plc_simulator/controllers/main_view.controller.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/models/find_replace_state.model.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/program_file.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/interfaces/program_file.interface.dart';
import 'package:plc_simulator/models/hmi_state.model.dart';
import 'package:plc_simulator/models/runtime_state.model.dart';
import 'package:plc_simulator/pages/editor/components/app_menu_bar.dart';

class _FakeFileService implements IProgramFileService {
  String? path;
  final files = <String, String>{};

  @override
  Future<String?> pickSavePath(String suggestedName) async => path;

  @override
  Future<String?> pickOpenPath() async => path;

  @override
  Future<void> write(String path, String contents) async =>
      files[path] = contents;

  @override
  Future<String> read(String path) async => files[path] ?? '';
}

void main() {
  late ProviderContainer container;
  late _FakeFileService fake;

  Future<void> pumpBar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    fake = _FakeFileService();
    container = ProviderContainer(
      overrides: [programFileServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: AppMenuBar()),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester, String menu) async {
    await tester.tap(find.text(menu));
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String menu, String item) async {
    await open(tester, menu);
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  bool enabled(WidgetTester tester, String item) =>
      tester
          .widget<MenuItemButton>(find.widgetWithText(MenuItemButton, item))
          .onPressed !=
      null;

  testWidgets('shows the six menus and their items', (tester) async {
    await pumpBar(tester);
    for (final menu in [
      'Arquivo',
      'Editar',
      'Exibir',
      'Comunicação',
      'Ferramentas',
      'Ajuda',
    ]) {
      expect(find.text(menu), findsOneWidget, reason: menu);
    }
    const items = {
      'Arquivo': ['Novo', 'Abrir...', 'Salvar', 'Exemplos'],
      'Editar': [
        'Inserir Linha',
        'Excluir Linha Selecionada',
        'Localizar...',
        'Substituir...',
      ],
      'Exibir': [
        'Ladder',
        'Supervisório',
        'Tabela de Dados (Data Files)',
        'Árvore do Projeto',
      ],
      'Comunicação': ['RUN', 'Passo (Step)', 'STOP'],
      'Ajuda': ['Sobre o Simulador'],
    };
    for (final e in items.entries) {
      await open(tester, e.key);
      for (final item in e.value) {
        expect(find.text(item), findsOneWidget, reason: '${e.key} > $item');
      }
      await tester.tapAt(const Offset(1300, 800));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Arquivo > Novo loads an empty program', (tester) async {
    await pumpBar(tester);
    expect(container.read(programProvider).program.rungs, isNotEmpty);
    await choose(tester, 'Arquivo', 'Novo');
    expect(container.read(programProvider).program.rungs, isEmpty);
  });

  testWidgets('Arquivo > Exemplos selects the clicked example', (tester) async {
    await pumpBar(tester);
    final examples = container.read(programProvider).examples;
    await open(tester, 'Arquivo');
    await tester.tap(find.text('Exemplos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(examples[1].name));
    await tester.pumpAndSettle();
    expect(container.read(programProvider).selected, 1);
  });

  testWidgets(
    'Arquivo > Salvar writes the file and reports it; cancelling shows nothing',
    (tester) async {
      await pumpBar(tester);
      await choose(tester, 'Arquivo', 'Salvar');
      expect(fake.files, isEmpty);
      expect(find.byType(SnackBar), findsNothing);

      fake.path = 'p.json';
      await choose(tester, 'Arquivo', 'Salvar');
      expect(fake.files.keys, ['p.json']);
      expect(find.text('Programa salvo.'), findsOneWidget);
    },
  );

  testWidgets(
    'Arquivo > Abrir... loads the file and reports it; cancelling shows nothing',
    (tester) async {
      await pumpBar(tester);
      await choose(tester, 'Arquivo', 'Abrir...');
      expect(find.byType(SnackBar), findsNothing);

      fake.path = 'p.json';
      fake.files['p.json'] = jsonEncode(programToJson(const Program([])));
      await choose(tester, 'Arquivo', 'Abrir...');
      expect(find.byType(SnackBar), findsOneWidget);
      expect(container.read(programProvider).program.rungs, isEmpty);
    },
  );

  testWidgets(
    'Editar inserts a rung and deletes the selected one only when stopped',
    (tester) async {
      await pumpBar(tester);
      final before = container.read(programProvider).program.rungs.length;
      await choose(tester, 'Editar', 'Inserir Linha');
      expect(container.read(programProvider).program.rungs.length, before + 1);
      expect(container.read(programProvider).selectedRung, before);

      await open(tester, 'Editar');
      expect(enabled(tester, 'Excluir Linha Selecionada'), isTrue);
      await tester.tap(find.text('Excluir Linha Selecionada'));
      await tester.pumpAndSettle();
      expect(container.read(programProvider).program.rungs.length, before);

      await open(tester, 'Editar');
      expect(
        enabled(tester, 'Excluir Linha Selecionada'),
        isFalse,
        reason: 'no rung selected',
      );
      await tester.tapAt(const Offset(1300, 800));
      await tester.pumpAndSettle();

      container.read(programProvider.notifier).selectRung(0);
      container.read(runtimeProvider.notifier).run();
      await tester.pump();
      await open(tester, 'Editar');
      expect(
        enabled(tester, 'Excluir Linha Selecionada'),
        isFalse,
        reason: 'running',
      );
      container.read(runtimeProvider.notifier).stop();
    },
  );

  testWidgets(
    'Exibir switches the view and toggles the data table, with check marks',
    (tester) async {
      await pumpBar(tester);
      await open(tester, 'Exibir');
      expect(
        find.byIcon(Icons.check),
        findsNWidgets(2),
      ); // Ladder + project tree
      await tester.tap(find.text('Supervisório'));
      await tester.pumpAndSettle();
      expect(container.read(mainViewProvider), MainView.hmi);

      await choose(tester, 'Exibir', 'Tabela de Dados (Data Files)');
      expect(container.read(dataTableProvider).open, isTrue);
      await open(tester, 'Exibir');
      expect(
        find.byIcon(Icons.check),
        findsNWidgets(3),
      ); // Supervisório + data table + project tree
      await tester.tap(find.text('Tabela de Dados (Data Files)'));
      await tester.pumpAndSettle();
      expect(container.read(dataTableProvider).open, isFalse);

      await choose(tester, 'Exibir', 'Ladder');
      expect(container.read(mainViewProvider), MainView.ladder);
    },
  );

  testWidgets(
    'Editar opens the find and replace dialogs; Exibir toggles the project tree',
    (tester) async {
      await pumpBar(tester);
      await choose(tester, 'Editar', 'Localizar...');
      expect(container.read(findReplaceProvider).isOpen, isTrue);
      expect(container.read(findReplaceProvider).mode, FindMode.find);
      await choose(tester, 'Editar', 'Substituir...');
      expect(container.read(findReplaceProvider).mode, FindMode.replace);

      expect(container.read(projectTreeProvider).isOpen, isTrue);
      await choose(tester, 'Exibir', 'Árvore do Projeto');
      expect(container.read(projectTreeProvider).isOpen, isFalse);
    },
  );

  testWidgets(
    'Comunicação menu runs, steps and stops, disabling RUN/STOP in their own mode',
    (tester) async {
      await pumpBar(tester);
      await open(tester, 'Comunicação');
      expect(enabled(tester, 'STOP'), isFalse);
      expect(enabled(tester, 'RUN'), isTrue);
      await tester.tap(find.text('Passo (Step)'));
      await tester.pumpAndSettle();
      expect(container.read(runtimeProvider).scanCount, 1);

      await choose(tester, 'Comunicação', 'RUN');
      expect(container.read(runtimeProvider).mode, RuntimeMode.run);
      await open(tester, 'Comunicação');
      expect(enabled(tester, 'RUN'), isFalse);
      expect(enabled(tester, 'STOP'), isTrue);
      await tester.tap(find.text('STOP'));
      await tester.pumpAndSettle();
      expect(container.read(runtimeProvider).mode, RuntimeMode.stop);
    },
  );

  testWidgets('Ajuda > Sobre o Simulador opens the about dialog', (
    tester,
  ) async {
    await pumpBar(tester);
    await choose(tester, 'Ajuda', 'Sobre o Simulador');
    expect(find.byType(AboutDialog), findsOneWidget);
    expect(find.text('Simulador CLP'), findsOneWidget);
  });
}

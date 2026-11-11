import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/controllers/hmi.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/models/hmi_state.model.dart';
import 'package:plc_simulator/pages/editor/editor.page.dart';

Future<ProviderContainer> pumpHmi(WidgetTester tester) async {
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
  await tester.tap(find.text('Supervisório'));
  await tester.pump();
  return container;
}

Future<void> addViaPalette(
  WidgetTester tester,
  HmiKind kind,
  String address,
) async {
  await tester.tap(find.byKey(ValueKey('palette-${kind.name}')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const ValueKey('hmi-address')), address);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

bool bit(ProviderContainer c, String a) =>
    c.read(runtimeProvider).bit(BitAddress.parse(a));

void main() {
  inputTests();
  testWidgets(
    'switching to Supervisório replaces the ladder with the palette',
    (tester) async {
      await pumpHmi(tester);
      expect(find.byKey(const ValueKey('palette-toggle')), findsOneWidget);
      expect(find.text('Data Files'), findsNothing);
      await tester.tap(find.text('Ladder'));
      await tester.pump();
      expect(find.byKey(const ValueKey('palette-toggle')), findsNothing);
      expect(find.text('Data Files'), findsOneWidget);
    },
  );

  testWidgets('dialog rejects an invalid address and a bit/word mismatch', (
    tester,
  ) async {
    final container = await pumpHmi(tester);
    await addViaPalette(tester, HmiKind.toggle, 'xx');
    expect(find.text('Endereço de bit inválido'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('hmi-address')), 'N7:0');
    await tester.tap(find.text('OK'));
    await tester.pump();
    expect(find.textContaining('endereço de bit'), findsOneWidget);
    expect(container.read(hmiProvider).widgets, isEmpty);
  });

  testWidgets('Chave on B3:0/0 flips the bit in the runtime', (tester) async {
    final container = await pumpHmi(tester);
    await addViaPalette(tester, HmiKind.toggle, 'b3:0/0');
    expect(find.text('OFF'), findsOneWidget);
    await tester.tap(find.text('OFF'));
    await tester.pump();
    await tester.pump();
    expect(bit(container, 'B3:0/0'), isTrue);
    expect(find.text('ON'), findsOneWidget);
  });

  testWidgets('Lâmpada reflects the bit value', (tester) async {
    final container = await pumpHmi(tester);
    await addViaPalette(tester, HmiKind.lamp, 'B3:0/2');
    final id = container.read(hmiProvider).widgets.single.id;
    expect(find.byKey(ValueKey('lamp-$id-off')), findsOneWidget);
    container
        .read(runtimeServiceProvider)
        .setBit(BitAddress.parse('B3:0/2'), true);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(ValueKey('lamp-$id-on')), findsOneWidget);
  });

  testWidgets('Display shows N7:0 and editing writes the word', (tester) async {
    final container = await pumpHmi(tester);
    container
        .read(runtimeServiceProvider)
        .writeWord(WordAddress.parse('N7:0'), 42);
    await addViaPalette(tester, HmiKind.display, 'N7:0');
    await tester.pump();
    expect(find.text('42'), findsOneWidget);
    await tester.tap(find.text('42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '777');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      container.read(runtimeProvider).word(WordAddress.parse('N7:0')),
      777,
    );
    expect(find.text('777'), findsOneWidget);
  });

  testWidgets('Botão sets the bit while pressed and clears it on release', (
    tester,
  ) async {
    final container = await pumpHmi(tester);
    await addViaPalette(tester, HmiKind.button, 'B3:0/4');
    final id = container.read(hmiProvider).widgets.single.id;
    final button = find.byKey(ValueKey('button-$id'));
    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump();
    expect(bit(container, 'B3:0/4'), isTrue);
    await gesture.up();
    await tester.pump();
    await tester.pump();
    expect(bit(container, 'B3:0/4'), isFalse);
  });

  testWidgets(
    'Barra fills proportionally; menu edits and deletes; handle drags',
    (tester) async {
      final container = await pumpHmi(tester);
      await tester.tap(find.byKey(const ValueKey('palette-bar')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('hmi-address')), 'N7:1');
      await tester.enterText(find.byKey(const ValueKey('hmi-max')), '200');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final id = container.read(hmiProvider).widgets.single.id;
      container
          .read(runtimeServiceProvider)
          .writeWord(WordAddress.parse('N7:1'), 100);
      await tester.pump();
      await tester.pump();
      expect(
        tester.getSize(find.byKey(ValueKey('bar-fill-$id'))).height,
        closeTo(58, 2),
      );

      final before = container.read(hmiProvider).widgets.single.x;
      await tester.drag(
        find.byKey(ValueKey('hmi-handle-$id')),
        const Offset(40, 0),
      );
      await tester.pump();
      expect(container.read(hmiProvider).widgets.single.x, greaterThan(before));

      await tester.longPress(find.byKey(ValueKey('hmi-handle-$id')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text('Editar').last,
      ); // the popup item; the first is the menu bar
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('hmi-label')), 'Tanque');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Tanque'), findsOneWidget);

      await tester.longPress(find.byKey(ValueKey('hmi-handle-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      expect(container.read(hmiProvider).widgets, isEmpty);
    },
  );
}

void inputTests() {
  testWidgets(
    'RUN: Chave on I:0/1 sticks across scans and sets the input image',
    (tester) async {
      final container = await pumpHmi(tester);
      container.read(runtimeProvider.notifier).run();
      await addViaPalette(tester, HmiKind.toggle, 'I:0/1');
      await tester.tap(find.text('OFF'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(bit(container, 'I:0/1'), isTrue);
      expect(container.read(runtimeProvider).input(1), isTrue);
      container.read(runtimeProvider.notifier).stop();
      await tester.pump();
    },
  );

  testWidgets('RUN: Botão on I:0/0 sets then clears the input image', (
    tester,
  ) async {
    final container = await pumpHmi(tester);
    container.read(runtimeProvider.notifier).run();
    await addViaPalette(tester, HmiKind.button, 'I:0/0');
    final id = container.read(hmiProvider).widgets.single.id;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('button-$id'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(bit(container, 'I:0/0'), isTrue);
    expect(container.read(runtimeProvider).input(0), isTrue);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(bit(container, 'I:0/0'), isFalse);
    expect(container.read(runtimeProvider).input(0), isFalse);
    container.read(runtimeProvider.notifier).stop();
    await tester.pump();
  });
}

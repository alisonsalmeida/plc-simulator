import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/io_panel.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/models/io_panel_state.model.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/io_panel.dart';
import 'package:plc_simulator/pages/editor/components/seven_segment_tile.dart';

Future<ProviderContainer> pumpPanel(
  WidgetTester tester, {
  bool associate = true,
}) async {
  tester.view.physicalSize = const Size(600, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(runtimeProvider);
  container.read(ioPanelTabProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: IoPanel())),
    ),
  );
  if (associate) {
    container.read(programProvider.notifier)
      ..setThumbwheelSlot(0)
      ..setSevenSegmentSlot(0);
    await tester.pump();
  }
  return container;
}

Future<void> openPeripherals(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('io-tab-peripherals')));
  await tester.pump();
}

List<bool> segments(WidgetTester tester, [int digit = 0]) {
  final paint = tester.widget<CustomPaint>(
    find.byKey(ValueKey('seven-segment-digit-$digit')),
  );
  return (paint.painter! as SevenSegmentPainter).segments;
}

Future<void> forceOutputs(
  WidgetTester tester,
  ProviderContainer c,
  int bits,
) async {
  final service = c.read(runtimeServiceProvider);
  for (var i = 0; i < 16; i++) {
    service.setForce(BitAddress(BitFile.output, 0, i), (bits >> i) & 1 == 1);
  }
  c.read(runtimeProvider.notifier).step();
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('peripherals live in their own tab', (tester) async {
    final c = await pumpPanel(tester);
    expect(find.text('Digitais'), findsOneWidget);
    expect(find.text('Analógicas'), findsOneWidget);
    expect(find.byKey(const ValueKey('thumbwheel-up-0')), findsNothing);
    expect(find.byKey(const ValueKey('seven-segment-digit-0')), findsNothing);
    await openPeripherals(tester);
    expect(c.read(ioPanelTabProvider), IoPanelTab.peripherals);
    expect(find.byKey(const ValueKey('thumbwheel-up-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('seven-segment-digit-0')), findsOneWidget);
    expect(find.text('I:0/12..15'), findsOneWidget);
    expect(find.text('O:0/12..15'), findsOneWidget);
  });

  testWidgets('unassociated peripherals show ⊘ and can be bound and unbound', (
    tester,
  ) async {
    final c = await pumpPanel(tester, associate: false);
    c.read(programProvider.notifier)
      ..setChassisSlot(1, ModuleCatalog.ib16)
      ..setChassisSlot(2, ModuleCatalog.ob16);
    await tester.pump();
    await openPeripherals(tester);
    expect(find.text('Thumbwheel (⊘)'), findsOneWidget);
    expect(find.text('Display 7 segmentos (⊘)'), findsOneWidget);
    expect(find.text('⊘ Não Associado'), findsNWidgets(2));
    expect(find.text('⊘'), findsNWidgets(4 + 4));
    expect(segments(tester), List.filled(7, false));

    // Unassociated dials write nothing.
    await tester.tap(find.byKey(const ValueKey('thumbwheel-up-0')));
    await tester.pump();
    expect(c.read(runtimeProvider).inputs & 0xFFFF, 0);

    // Bind the thumbwheel to slot 1: the digit value is driven.
    await tester.tap(find.byKey(const ValueKey('thumbwheel-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 1').last);
    await tester.pumpAndSettle();
    expect(find.text('Thumbwheel (I:1)'), findsOneWidget);
    expect(find.text('I:1/0..3'), findsOneWidget);
    final element = ioElement(BitFile.input, 1, null)!;
    expect(c.read(runtimeProvider).data[BitFile.input]?[element], 1);

    // Unbind: bits are cleared and the ⊘ symbol returns.
    await tester.tap(find.byKey(const ValueKey('thumbwheel-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⊘ Não Associado').last);
    await tester.pumpAndSettle();
    expect(c.read(programProvider).program.ioMapping.thumbwheelSlot, isNull);
    expect(c.read(runtimeProvider).data[BitFile.input]?[element] ?? 0, 0);
    expect(find.text('Thumbwheel (⊘)'), findsOneWidget);

    // Bind and unbind the display.
    await tester.tap(find.byKey(const ValueKey('seven-segment-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Display 7 segmentos (O:2)'), findsOneWidget);
    expect(find.text('O:2/0..3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('seven-segment-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⊘ Não Associado').last);
    await tester.pumpAndSettle();
    expect(c.read(programProvider).program.ioMapping.sevenSegmentSlot, isNull);
    expect(find.text('Display 7 segmentos (⊘)'), findsOneWidget);
  });

  testWidgets('4-digit thumbwheel drives all 16 bits of I:0', (tester) async {
    final c = await pumpPanel(tester);
    await openPeripherals(tester);
    // 1234 decimal digits -> BCD 0x1234.
    for (final entry in {0: 4, 1: 3, 2: 2, 3: 1}.entries) {
      for (var n = 0; n < entry.value; n++) {
        await tester.tap(find.byKey(ValueKey('thumbwheel-up-${entry.key}')));
      }
    }
    await tester.pump();
    expect(c.read(runtimeProvider).inputs & 0xFFFF, 0x1234);
    expect(find.text('Valor: 1234  |  BCD: 0x1234'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thumbwheel-down-0')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-down-0')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-down-0')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-down-0')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-down-0')));
    await tester.pump();
    expect(c.read(runtimeProvider).inputs & 0xFFFF, 0x1239); // wraps 0 -> 9
  });

  testWidgets('thumbwheel digit count hides dials and clears their bits', (
    tester,
  ) async {
    final c = await pumpPanel(tester);
    await openPeripherals(tester);
    await tester.tap(find.byKey(const ValueKey('thumbwheel-up-3')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-up-0')));
    await tester.pump();
    expect(c.read(runtimeProvider).inputs & 0xFFFF, 0x1001);
    await tester.tap(find.byKey(const ValueKey('thumbwheel-digits')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2 dígitos').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('thumbwheel-dial-2')), findsNothing);
    expect(find.byKey(const ValueKey('thumbwheel-dial-1')), findsOneWidget);
    expect(c.read(runtimeProvider).inputs & 0xFFFF, 0x0001);
  });

  testWidgets('4-digit 7-segment display reads all 16 bits of O:0 in BCD', (
    tester,
  ) async {
    final c = await pumpPanel(tester);
    await openPeripherals(tester);
    await forceOutputs(tester, c, 0x1234);
    const digits = <int, List<bool>>{
      1: [false, true, true, false, false, false, false],
      2: [true, true, false, true, true, false, true],
      3: [true, true, true, true, false, false, true],
      4: [false, true, true, false, false, true, true],
    };
    expect(segments(tester, 3), digits[1]);
    expect(segments(tester, 2), digits[2]);
    expect(segments(tester, 1), digits[3]);
    expect(segments(tester, 0), digits[4]);
  });

  testWidgets('7-segment display direct mode uses O:0/0..6', (tester) async {
    final c = await pumpPanel(tester);
    await openPeripherals(tester);
    await tester.tap(find.byKey(const ValueKey('seven-segment-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Segmentos Diretos').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('seven-segment-digit-1')), findsNothing);
    await forceOutputs(tester, c, 0x41); // a + g
    expect(segments(tester), [true, false, false, false, false, false, true]);
  });

  testWidgets('peripherals can be wired to installed chassis slots', (
    tester,
  ) async {
    final c = await pumpPanel(tester);
    final program = c.read(programProvider.notifier);
    program.setChassisSlot(1, ModuleCatalog.ib16);
    program.setChassisSlot(2, ModuleCatalog.ob16);
    await tester.pump();
    await openPeripherals(tester);

    await tester.tap(find.byKey(const ValueKey('thumbwheel-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 1').last);
    await tester.pumpAndSettle();
    expect(c.read(programProvider).program.ioMapping.thumbwheelSlot, 1);
    expect(find.text('Thumbwheel (I:1)'), findsOneWidget);
    expect(find.text('I:1/12..15'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('thumbwheel-up-0')));
    await tester.tap(find.byKey(const ValueKey('thumbwheel-up-0')));
    await tester.pump();
    final runtime = c.read(runtimeProvider);
    expect(runtime.data[BitFile.input]?[ioElement(BitFile.input, 1, null)!], 2);
    expect(runtime.inputs & 0xFFFF, 0);

    await tester.tap(find.byKey(const ValueKey('seven-segment-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 2').last);
    await tester.pumpAndSettle();
    expect(c.read(programProvider).program.ioMapping.sevenSegmentSlot, 2);
    expect(find.text('O:2/0..3'), findsOneWidget);
    c
        .read(runtimeProvider.notifier)
        .setBit(
          BitAddress(BitFile.output, ioElement(BitFile.output, 2, null)!, 1),
          true,
        ); // BCD 2
    await tester.pump();
    await tester.pump();
    expect(segments(tester), [true, true, false, true, true, false, true]); // 2
  });

  testWidgets('digital input and output slots can be remapped', (tester) async {
    final c = await pumpPanel(tester);
    final program = c.read(programProvider.notifier);
    program.setChassisSlot(1, ModuleCatalog.ib16);
    program.setChassisSlot(2, ModuleCatalog.ob16);
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('digital-input-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 1').last);
    await tester.pumpAndSettle();
    expect(c.read(programProvider).program.ioMapping.digitalInputSlot, 1);
    expect(find.text('Entradas (I:1)'), findsOneWidget);
    expect(find.text('I:1/0'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('digital-output-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slot 2').last);
    await tester.pumpAndSettle();
    expect(find.text('Saídas (O:2)'), findsOneWidget);
    expect(find.text('O:2/0'), findsOneWidget);

    c.read(runtimeProvider.notifier).setInput(3, true);
    c.read(runtimeProvider.notifier).step();
    await tester.pump();
    final data = c.read(runtimeProvider).data;
    expect((data[BitFile.input]?[ioElement(BitFile.input, 1, null)!] ?? 0) & 8, 8);
    expect(data[BitFile.input]?[0] ?? 0, 0);

    final service = c.read(runtimeServiceProvider);
    service.setForce(BitAddress(BitFile.output, ioElement(BitFile.output, 2, null)!, 5), true);
    c.read(runtimeProvider.notifier).step();
    await tester.pump();
    expect(c.read(runtimeProvider).output(5), true);
    expect(c.read(runtimeProvider).output(4), false);
  });

  testWidgets('7-segment BCD example loads and converts the thumbwheel digit', (
    tester,
  ) async {
    final c = await pumpPanel(tester);
    final index = ladderExamples.indexWhere(
      (e) => e.name == 'Display 7 segmentos e BCD (TOD / FRD)',
    );
    expect(index, isNonNegative);
    c.read(programProvider.notifier).select(index);
    await tester.pump();
    await openPeripherals(tester); // selecting a program resets the tab
    final runtime = c.read(runtimeProvider.notifier);
    runtime.setInput(0, true);
    runtime.setInput(2, true); // BCD 5
    runtime.step();
    await tester.pump();
    await tester.pump();
    expect(c.read(runtimeProvider).outputs & 0xFFFF, 0x6); // 5 + 1 = 6 in BCD
    expect(segments(tester), [true, false, true, true, true, true, true]); // 6
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/project_tree.controller.dart';
import 'package:plc_simulator/controllers/analog_io.controller.dart';
import 'package:plc_simulator/controllers/data_edit.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/editor/components/analog_chart.dart';
import 'package:plc_simulator/pages/editor/components/io_panel.dart';

int analogExample() =>
    ladderExamples.indexWhere((e) => e.name.startsWith('Analógico'));

Future<ProviderContainer> pumpPanel(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  container.read(projectTreeProvider.notifier).close();
  addTearDown(container.dispose);
  container.read(programProvider.notifier).select(analogExample());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(body: SizedBox(width: 340, child: IoPanel())),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets(
    'moving the I:1.1 slider (0-10 V) writes the raw count to the runtime',
    (tester) async {
      final container = await pumpPanel(tester);
      expect(find.text('Entradas analógicas (I:1)'), findsOneWidget);
      expect(find.text('Saídas analógicas (O:2)'), findsOneWidget);
      final slider = find.byKey(const ValueKey('analog-in-slider-1'));
      await tester.ensureVisible(slider);
      await tester.drag(slider, const Offset(500, 0)); // far right: full scale
      await tester.pump();
      expect(container.read(runtimeProvider).analogInputs[1], 32767);
      expect(find.text('10,0 V'), findsOneWidget);
    },
  );

  testWidgets('I:1.0 is 4-20 mA by default; the controller maps mA to counts', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    container.read(analogIoProvider.notifier).setInputPhysical(0, 12);
    await tester.pump();
    await tester.pump();
    expect(container.read(runtimeProvider).analogInputs[0], closeTo(9830, 1));
    expect(find.text('12,0 mA'), findsOneWidget);
  });

  testWidgets('analog example: 20 mA -> level 100 %, 10 V out, high alarm', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    final runtime = container.read(runtimeProvider.notifier);
    container.read(analogIoProvider.notifier).setInputPhysical(0, 20);
    for (var i = 0; i < 3; i++) {
      runtime.step();
      await tester.pump(); // let the state stream deliver
    }
    await tester.pump();
    final s = container.read(runtimeProvider);
    expect(s.word(WordAddress.parse('N7:1')), closeTo(100, 1));
    expect(s.analogOutputs[0], closeTo(32764, 5));
    expect(s.output(0), isTrue);
    expect(s.output(1), isFalse);
    await tester.pump();
    expect(find.text('10,0 V'), findsOneWidget);
  });

  testWidgets(
    'analog example: 4 mA -> level 0 %, 0 V out, low alarm; STOP clears outputs',
    (tester) async {
      final container = await pumpPanel(tester);
      final runtime = container.read(runtimeProvider.notifier);
      container.read(analogIoProvider.notifier).setInputPhysical(0, 4);
      for (var i = 0; i < 3; i++) {
        runtime.step();
        await tester.pump(); // let the state stream deliver
      }
      var s = container.read(runtimeProvider);
      expect(s.word(WordAddress.parse('N7:1')), closeTo(0, 1));
      expect(s.analogOutputs[0], closeTo(0, 5));
      expect(s.output(1), isTrue);
      expect(s.output(0), isFalse);

      container
          .read(analogIoProvider.notifier)
          .setInputPhysical(0, 12); // mid level
      runtime.step();
      await tester.pump();
      s = container.read(runtimeProvider);
      expect(s.word(WordAddress.parse('N7:1')), closeTo(50, 1));
      expect(s.analogOutputs[0], closeTo(16382, 20));
      runtime.stop();
      await tester.pump();
      expect(container.read(runtimeProvider).analogOutputs, [0, 0]);
    },
  );

  testWidgets(
    'noise button toggles, makes the count fluctuate and off restores the base',
    (tester) async {
      final container = await pumpPanel(tester);
      final runtime = container.read(runtimeProvider.notifier);
      container
          .read(analogIoProvider.notifier)
          .setInputPhysical(1, 5); // mid scale, 0-10 V
      await tester.pump();
      final base = container.read(runtimeProvider).analogInputs[1];
      final button = find.byKey(const ValueKey('analog-in-noise-1'));
      await tester.ensureVisible(button);
      expect(container.read(analogIoProvider).noiseEnabled[1], isFalse);

      await tester.tap(button);
      await tester.pump();
      expect(container.read(analogIoProvider).noiseEnabled[1], isTrue);

      final seen = <int>{};
      for (var i = 0; i < 20; i++) {
        runtime.step();
        await tester.pump();
        final v = container.read(runtimeProvider).analogInputs[1];
        expect((v - base).abs(), lessThanOrEqualTo(500));
        seen.add(v);
      }
      expect(seen.length, greaterThan(1));

      await tester.tap(button);
      await tester.pump();
      expect(container.read(analogIoProvider).noiseEnabled[1], isFalse);
      expect(container.read(runtimeProvider).analogInputs[1], base);
      runtime.step();
      await tester.pump();
      expect(container.read(runtimeProvider).analogInputs[1], base);
    },
  );

  testWidgets('tabs switch between digital and analog I/O', (tester) async {
    await pumpPanel(tester);
    expect(find.text('Entradas analógicas (I:1)'), findsOneWidget);
    expect(find.text('Entradas (I:0)'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('io-tab-digital')));
    await tester.pump();
    expect(find.text('Entradas (I:0)'), findsOneWidget);
    expect(find.text('Saídas (O:0)'), findsOneWidget);
    expect(find.text('Entradas analógicas (I:1)'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('io-tab-analog')));
    await tester.pump();
    expect(find.text('Saídas analógicas (O:2)'), findsOneWidget);
  });

  testWidgets('chart toggle expands the waveform on input and output tiles', (
    tester,
  ) async {
    await pumpPanel(tester);
    expect(find.byType(AnalogWaveformChart), findsNothing);
    for (final address in ['I:1.0', 'O:2.0']) {
      final toggle = find.byKey(ValueKey('$address-chart-toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }
    expect(find.byType(AnalogWaveformChart), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('I:1.0-chart-toggle')));
    await tester.pump();
    expect(find.byType(AnalogWaveformChart), findsOneWidget);
  });

  testWidgets('Data Files writes to I:1.x go through the analog input image', (
    tester,
  ) async {
    final container = await pumpPanel(tester);
    container
        .read(dataEditProvider.notifier)
        .writeWord(WordAddress.parse('I:1.2'), 5000);
    container.read(runtimeProvider.notifier).step();
    await tester.pump();
    expect(container.read(runtimeProvider).analogInputs[2], 5000);
    expect(
      container.read(runtimeProvider).word(WordAddress.parse('I:1.2')),
      5000,
    );
    container
        .read(dataEditProvider.notifier)
        .setBit(BitAddress.parse('I:1.2/15'), true);
    await tester.pump();
    expect(container.read(runtimeProvider).analogInputs[2], 5000 | 0x8000);
  });
}

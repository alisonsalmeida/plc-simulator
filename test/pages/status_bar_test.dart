import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/pages/editor/components/status_bar.dart';

void main() {
  testWidgets(
    'status bar shows the panels and follows mode and rung selection',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: StatusBar(),
              ),
            ),
          ),
        ),
      );
      for (final t in [
        'Para Ajuda, pressione F1',
        'Scan: 10 ms',
        'PROG',
        'REMOTE',
        'Sem Forçamentos',
        'Driver: Emulado',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      container.read(programProvider.notifier).selectRung(0);
      container.read(runtimeProvider.notifier).run();
      await tester.pump();
      expect(find.text('Linha 0 selecionada'), findsOneWidget);
      expect(find.text('RUN'), findsOneWidget);
      container.read(runtimeProvider.notifier).stop();
      await tester.pump();
    },
  );
}

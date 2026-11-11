import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';
import 'package:plc_simulator/pages/data_table/components/bit_file_grid.dart';
import 'package:plc_simulator/pages/editor/components/status_bar.dart';

void main() {
  testWidgets('status bar shows the number of active forces', (tester) async {
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
            body: Align(alignment: Alignment.bottomCenter, child: StatusBar()),
          ),
        ),
      ),
    );
    expect(find.text('Sem Forçamentos'), findsOneWidget);
    container
        .read(runtimeServiceProvider)
        .setForce(const BitAddress(BitFile.input, 0, 0), true);
    await tester.pump();
    expect(find.text('Forças: 1 ativas'), findsOneWidget);
    container.read(runtimeProvider.notifier).clearAllForces();
    await tester.pump();
    await tester.pump();
    expect(find.text('Sem Forçamentos'), findsOneWidget);
  });

  testWidgets('bit grid force dialog sets and removes a force', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(runtimeProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: BitFileGrid(
                  file: BitFile.output,
                  selected: null,
                  onSelect: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    const o0 = BitAddress(BitFile.output, 0, 0);
    await tester.tap(find.byKey(const ValueKey('bit-O:0/0')));
    await tester.pumpAndSettle();
    expect(find.text('Remover Forçamento'), findsNothing);
    await tester.tap(find.text('Forçar ON (1)'));
    await tester.pumpAndSettle();
    expect(container.read(runtimeProvider).forceOf(o0), isTrue);
    expect(container.read(runtimeProvider).bit(o0), isTrue);
    await tester.tap(find.byKey(const ValueKey('bit-O:0/0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover Forçamento'));
    await tester.pumpAndSettle();
    expect(container.read(runtimeProvider).hasForces, isFalse);
  });

  test('curriculum examples are bundled and load', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    for (final name in [
      'Partida com reversão (intertravamento)',
      'Partida estrela-triângulo (temporizada)',
      'Totalizador de lotes (ADD / MOD)',
      'Processo de tanque e histerese (analógico + IHM)',
    ]) {
      final index = ladderExamples.indexWhere((e) => e.name == name);
      expect(index, isNonNegative, reason: name);
      container.read(programProvider.notifier).select(index);
      expect(container.read(programProvider).program.rungs, isNotEmpty);
    }
    expect(ladderExamples.last.name, 'Novo programa');
  });
}

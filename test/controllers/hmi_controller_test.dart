import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_simulator/controllers/hmi.controller.dart';
import 'package:plc_simulator/controllers/main_view.controller.dart';
import 'package:plc_simulator/models/hmi_state.model.dart';

void main() {
  late ProviderContainer container;
  late HmiController hmi;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    hmi = container.read(hmiProvider.notifier);
  });

  List<HmiWidget> widgets() => container.read(hmiProvider).widgets;

  test('add stores the canonical address and defaults the label to it', () {
    expect(hmi.add(HmiKind.toggle, ' b3:0/1 '), isNull);
    expect(widgets().single.address, 'B3:0/1');
    expect(widgets().single.label, 'B3:0/1');
    expect(hmi.add(HmiKind.lamp, 'T4:0/DN', label: 'Pronto'), isNull);
    expect(widgets().last.label, 'Pronto');
    expect(widgets().map((w) => w.id).toSet().length, 2);
  });

  test('rejects invalid addresses and bit/word mismatches with pt-BR errors', () {
    expect(hmi.add(HmiKind.toggle, 'zz'), 'Endereço de bit inválido');
    expect(hmi.add(HmiKind.display, 'zz'), 'Endereço de palavra inválido');
    expect(hmi.add(HmiKind.lamp, 'N7:0'), contains('endereço de bit'));
    expect(hmi.add(HmiKind.display, 'B3:0/0'), contains('endereço de palavra'));
    expect(hmi.add(HmiKind.bar, 'N7:0', min: 10, max: 10), isNotNull);
    expect(widgets(), isEmpty);
  });

  test('update changes address and label, keeping position; invalid is rejected', () {
    hmi.add(HmiKind.display, 'N7:0');
    final id = widgets().single.id;
    hmi.move(id, 50, 60);
    expect(hmi.update(id, 'N7:5', label: 'Vazão'), isNull);
    expect(widgets().single.address, 'N7:5');
    expect(widgets().single.label, 'Vazão');
    expect(widgets().single.x, 50);
    expect(hmi.update(id, 'B3:0/0'), isNotNull);
    expect(widgets().single.address, 'N7:5');
  });

  test('move clamps to the canvas origin and remove deletes', () {
    hmi.add(HmiKind.button, 'B3:0/0');
    final id = widgets().single.id;
    hmi.move(id, -5, 30);
    expect((widgets().single.x, widgets().single.y), (0, 30));
    hmi.remove(id);
    expect(widgets(), isEmpty);
  });

  test('main view starts on the ladder and can switch', () {
    expect(container.read(mainViewProvider), MainView.ladder);
    container.read(mainViewProvider.notifier).select(MainView.hmi);
    expect(container.read(mainViewProvider), MainView.hmi);
  });
}

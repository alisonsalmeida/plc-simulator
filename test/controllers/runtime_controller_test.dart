import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/models/runtime_state.model.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('stepping the start/stop example seals the motor in and the stop button drops it', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(0);
    final runtime = container.read(runtimeProvider.notifier);
    expect(container.read(runtimeProvider).mode, RuntimeMode.stop);

    runtime.setInput(0, true); // press start
    runtime.step();
    runtime.setInput(0, false); // release
    runtime.step();
    await settle();
    expect(container.read(runtimeProvider).output(0), isTrue);
    expect(container.read(runtimeProvider).mode, RuntimeMode.step);

    runtime.setInput(1, true); // press stop
    runtime.step();
    await settle();
    expect(container.read(runtimeProvider).output(0), isFalse);

    runtime.stop();
    await settle();
    expect(container.read(runtimeProvider).mode, RuntimeMode.stop);
  });

  test('selecting another example reloads the runtime in STOP', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(runtimeProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(runtimeProvider.notifier).run();
    await settle();
    expect(container.read(runtimeProvider).mode, RuntimeMode.run);
    container.read(programProvider.notifier).select(1);
    await settle();
    expect(container.read(runtimeProvider).mode, RuntimeMode.stop);
  });
}

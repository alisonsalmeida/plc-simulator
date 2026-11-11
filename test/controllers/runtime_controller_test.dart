import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/core/examples.dart';
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

  test('stepping the TON example advances the timer 10 ms per step and exposes ACC', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(
          ladderExamples.indexWhere((e) => e.name.contains('TON')),
        );
    final runtime = container.read(runtimeProvider.notifier);
    const timer = ElementAddress(BitFile.timer, 0);

    runtime.setInput(0, true); // B1
    for (var i = 0; i < 3; i++) {
      runtime.step();
    }
    runtime.setInput(0, false);
    for (var i = 0; i < 197; i++) {
      runtime.step();
    }
    await settle();
    var state = container.read(runtimeProvider);
    expect(state.pre(timer), 5);
    expect(state.acc(timer), 2); // 200 steps x 10 ms = 2 s (+ the first step)
    expect(state.bit(BitAddress.parse('T4:0/EN')), isTrue);
    expect(state.bit(BitAddress.parse('T4:0/DN')), isFalse);
    expect(state.output(0), isFalse);

    for (var i = 0; i < 300; i++) {
      runtime.step();
    }
    await settle();
    state = container.read(runtimeProvider);
    expect(state.acc(timer), 5);
    expect(state.bit(BitAddress.parse('T4:0/DN')), isTrue);
    expect(state.output(0), isTrue);

    runtime.setInput(1, true); // B0
    runtime.step();
    await settle();
    state = container.read(runtimeProvider);
    expect(state.output(0), isFalse);
    expect(state.acc(timer), 0);
  });

  test('stepping the CTU example counts parts, lights the lamp at 10 and RES clears', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(programProvider.notifier).select(
          ladderExamples.indexWhere((e) => e.name.contains('CTU')),
        );
    final runtime = container.read(runtimeProvider.notifier);
    const counter = ElementAddress(BitFile.counter, 0);
    for (var i = 0; i < 10; i++) {
      runtime.setInput(2, true);
      runtime.step();
      runtime.setInput(2, false);
      runtime.step();
    }
    await settle();
    expect(container.read(runtimeProvider).acc(counter), 10);
    expect(container.read(runtimeProvider).output(1), isTrue);
    runtime.setInput(3, true);
    runtime.step();
    runtime.step(); // the lamp rung sits above RES, so it drops one scan later
    await settle();
    expect(container.read(runtimeProvider).acc(counter), 0);
    expect(container.read(runtimeProvider).output(1), isFalse);
  });
}

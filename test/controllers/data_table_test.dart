import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/data_edit.controller.dart';
import 'package:plc_simulator/controllers/data_table.controller.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/rung_edit.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/core/examples.dart';

Future<void> settle() => Future<void>.delayed(Duration.zero);

int moveIndex() => ladderExamples.indexWhere((e) => e.name.contains('MOV'));

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(runtimeProvider, (_, _) {});
    container.read(programProvider.notifier).select(moveIndex());
    await settle();
  });

  test('writeWord and toggleBit work in STOP and survive a program edit', () async {
    final edit = container.read(dataEditProvider.notifier);
    edit.writeWord(WordAddress.parse('N7:3'), 42);
    edit.toggleBit(BitAddress.parse('B3:0/2'));
    await settle();
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:3')), 42);
    expect(container.read(runtimeProvider).bit(BitAddress.parse('B3:0/2')), isTrue);

    container.read(rungEditProvider.notifier).addRung();
    await settle();
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:3')), 42);
    expect(container.read(runtimeProvider).bit(BitAddress.parse('B3:0/2')), isTrue);
  });

  test('switching example resets the data files', () async {
    container.read(dataEditProvider.notifier).writeWord(WordAddress.parse('N7:3'), 42);
    await settle();
    container.read(programProvider.notifier).select(0);
    await settle();
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:3')), 0);
  });

  test('MOV 100, MVM low nibble into O:0 and CLR', () async {
    final runtime = container.read(runtimeProvider.notifier);
    runtime.setInput(0, true);
    runtime.step();
    runtime.setInput(0, false);
    runtime.setInput(1, true);
    runtime.step();
    await settle();
    final state = container.read(runtimeProvider);
    expect(state.word(WordAddress.parse('N7:0')), 100);
    expect(state.output(2), isTrue); // 100 & 0xF = 4
    expect(state.output(0), isFalse);

    runtime.setInput(1, false);
    runtime.setInput(2, true);
    runtime.step();
    await settle();
    expect(container.read(runtimeProvider).word(WordAddress.parse('N7:0')), 0);
  });

  test('heightFraction defaults to 0.4, clamps to [0.15, 0.85] and survives hide/show', () {
    final table = container.read(dataTableProvider.notifier);
    expect(container.read(dataTableProvider).heightFraction, 0.4);
    table.setHeightFraction(0.01);
    expect(container.read(dataTableProvider).heightFraction, 0.15);
    table.setHeightFraction(2);
    expect(container.read(dataTableProvider).heightFraction, 0.85);
    table.setHeightFraction(0.6);
    table.show();
    table.hide();
    table.show();
    expect(container.read(dataTableProvider).heightFraction, 0.6);
  });
}

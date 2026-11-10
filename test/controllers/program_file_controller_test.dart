import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plc_core/plc_core.dart';
import 'package:plc_simulator/controllers/program.controller.dart';
import 'package:plc_simulator/controllers/program_file.controller.dart';
import 'package:plc_simulator/controllers/runtime.controller.dart';
import 'package:plc_simulator/interfaces/program_file.interface.dart';
import 'package:plc_simulator/models/program_file_result.model.dart';
import 'package:plc_simulator/models/runtime_state.model.dart';

class FakeProgramFileService implements IProgramFileService {
  final files = <String, String>{};
  String? nextPath;

  @override
  Future<String?> pickSavePath(String suggestedName) async => nextPath;

  @override
  Future<String?> pickOpenPath() async => nextPath;

  @override
  Future<void> write(String path, String contents) async =>
      files[path] = contents;

  @override
  Future<String> read(String path) async =>
      files[path] ?? (throw StateError('missing file $path'));
}

Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeProgramFileService fake;
  late ProviderContainer container;

  setUp(() {
    fake = FakeProgramFileService();
    container = ProviderContainer(
      overrides: [programFileServiceProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);
  });

  const other =
      '{"format":"plc-simulator-program","version":1,"rungs":['
      '{"elements":[{"op":"XIC","address":"I:0/3"},{"op":"OTE","address":"O:0/3"}]}],'
      '"symbols":{},"descriptions":{}}';

  test('save writes the JSON of the current program', () async {
    fake.nextPath = 'a.json';
    final result = await container.read(programFileProvider.notifier).save();
    expect(result.status, ProgramFileStatus.done);
    final program = container.read(programProvider).program;
    expect(jsonDecode(fake.files['a.json']!), programToJson(program));
  });

  test('open replaces the program and resets the runtime', () async {
    final sub = container.listen(runtimeProvider, (_, _) {});
    addTearDown(sub.close);
    final runtime = container.read(runtimeProvider.notifier);
    runtime.setInput(0, true);
    runtime.run();
    await settle();
    expect(container.read(runtimeProvider).mode, RuntimeMode.run);

    fake.files['b.json'] = other;
    fake.nextPath = 'b.json';
    final result = await container.read(programFileProvider.notifier).open();
    await settle();
    expect(result.status, ProgramFileStatus.done);
    final program = container.read(programProvider).program;
    expect(program.rungs, hasLength(1));
    expect(
      (program.rungs.single.elements.first as Instruction).target,
      'I:0/3',
    );
    expect(container.read(runtimeProvider).mode, RuntimeMode.stop);
    expect(container.read(runtimeProvider).input(0), isFalse);
  });

  test(
    'open with invalid JSON keeps the program and returns the error',
    () async {
      final before = container.read(programProvider).program;
      for (final bad in ['not json', '[]', '{"format":"x"}']) {
        fake.files['c.json'] = bad;
        fake.nextPath = 'c.json';
        final result = await container
            .read(programFileProvider.notifier)
            .open();
        expect(result.status, ProgramFileStatus.error, reason: bad);
        expect(result.message, startsWith('Arquivo inválido: '), reason: bad);
        expect(container.read(programProvider).program, same(before));
      }
    },
  );

  test(
    'an unreadable file returns an I/O error and keeps the program',
    () async {
      final before = container.read(programProvider).program;
      fake.nextPath = 'missing.json';
      final result = await container.read(programFileProvider.notifier).open();
      expect(result.status, ProgramFileStatus.error);
      expect(result.message, startsWith('Não foi possível ler o arquivo: '));
      expect(container.read(programProvider).program, same(before));
    },
  );

  test('cancelling the dialog changes nothing', () async {
    final before = container.read(programProvider).program;
    fake.nextPath = null;
    final controller = container.read(programFileProvider.notifier);
    expect((await controller.open()).status, ProgramFileStatus.cancelled);
    expect((await controller.save()).status, ProgramFileStatus.cancelled);
    expect(fake.files, isEmpty);
    expect(container.read(programProvider).program, same(before));
  });
}

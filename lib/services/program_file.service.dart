import 'dart:io';

import 'package:file_selector/file_selector.dart';

import '../interfaces/program_file.interface.dart';

/// Program files on disk, chosen with the platform file dialogs. Only `.json` is offered.
class ProgramFileService implements IProgramFileService {
  static const _jsonType = XTypeGroup(
    label: 'Programa (JSON)',
    extensions: ['json'],
  );

  @override
  Future<String?> pickSavePath(String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [_jsonType],
    );
    return location?.path;
  }

  @override
  Future<String?> pickOpenPath() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonType]);
    return file?.path;
  }

  @override
  Future<void> write(String path, String contents) =>
      File(path).writeAsString(contents);

  @override
  Future<String> read(String path) => File(path).readAsString();
}

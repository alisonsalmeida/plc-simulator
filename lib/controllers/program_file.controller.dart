import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:plc_core/plc_core.dart';

import '../interfaces/program_file.interface.dart';
import '../models/program_file_result.model.dart';
import '../services/program_file.service.dart';
import 'program.controller.dart';

final programFileServiceProvider = Provider<IProgramFileService>(
  (ref) => ProgramFileService(),
);

/// Saves the program to a JSON file and loads one back. Both actions return a
/// [ProgramFileResult] with the pt-BR message for the UI; state is the last result.
class ProgramFileController extends Notifier<ProgramFileResult?> {
  static const suggestedName = 'programa.json';

  @override
  ProgramFileResult? build() => null;

  Future<ProgramFileResult> save() async {
    final service = ref.read(programFileServiceProvider);
    try {
      final path = await service.pickSavePath(suggestedName);
      if (path == null) {
        return _done(const ProgramFileResult(ProgramFileStatus.cancelled));
      }
      final json = programToJson(ref.read(programProvider).program);
      await service.write(
        path,
        const JsonEncoder.withIndent('  ').convert(json),
      );
      return _done(
        const ProgramFileResult(ProgramFileStatus.done, 'Programa salvo.'),
      );
    } catch (e) {
      return _done(
        ProgramFileResult(
          ProgramFileStatus.error,
          'Não foi possível gravar o arquivo: ${_text(e)}',
        ),
      );
    }
  }

  /// Loads the chosen file as the current program; on any error the program is untouched.
  Future<ProgramFileResult> open() async {
    final service = ref.read(programFileServiceProvider);
    final String contents;
    try {
      final path = await service.pickOpenPath();
      if (path == null) {
        return _done(const ProgramFileResult(ProgramFileStatus.cancelled));
      }
      contents = await service.read(path);
    } catch (e) {
      return _done(
        ProgramFileResult(
          ProgramFileStatus.error,
          'Não foi possível ler o arquivo: ${_text(e)}',
        ),
      );
    }
    try {
      final json = jsonDecode(contents);
      if (json is! Map<String, Object?>) {
        throw const FormatException('the file does not hold a JSON object');
      }
      ref.read(programProvider.notifier).loadProgram(programFromJson(json));
      return _done(
        const ProgramFileResult(ProgramFileStatus.done, 'Programa aberto.'),
      );
    } on FormatException catch (e) {
      return _done(
        ProgramFileResult(
          ProgramFileStatus.error,
          'Arquivo inválido: ${e.message}',
        ),
      );
    }
  }

  ProgramFileResult _done(ProgramFileResult result) => state = result;

  String _text(Object e) =>
      e is FileSystemException ? (e.osError?.message ?? e.message) : '$e';
}

final programFileProvider =
    NotifierProvider<ProgramFileController, ProgramFileResult?>(
      ProgramFileController.new,
    );

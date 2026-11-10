enum ProgramFileStatus { done, cancelled, error }

/// Outcome of saving or opening a program file; [message] is the pt-BR text for the user.
class ProgramFileResult {
  const ProgramFileResult(this.status, [this.message = '']);

  final ProgramFileStatus status;
  final String message;
}

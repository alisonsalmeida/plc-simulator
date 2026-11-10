/// Reads and writes program files chosen by the user: the dialogs and the disk access.
abstract class IProgramFileService {
  /// Asks where to save; returns the chosen path, or null if the user cancelled.
  Future<String?> pickSavePath(String suggestedName);

  /// Asks which file to open; returns the chosen path, or null if the user cancelled.
  Future<String?> pickOpenPath();

  Future<void> write(String path, String contents);
  Future<String> read(String path);
}

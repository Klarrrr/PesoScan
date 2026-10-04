import 'dart:io';

/// True if [error] means "the phone's storage is full".
bool isStorageFullError(Object error) {
  if (error is FileSystemException) {
    final os = error.osError;
    if (os != null && os.errorCode == 28) return true; // ENOSPC: no space left
    final text = '${error.message} ${os?.message ?? ''}'.toLowerCase();
    return text.contains('no space left') || text.contains('disk full');
  }
  final text = error.toString().toLowerCase();
  return text.contains('no space left') ||
      text.contains('disk is full') || // SQLite: "database or disk is full"
      text.contains('sqlite_full') ||
      text.contains('enospc');
}

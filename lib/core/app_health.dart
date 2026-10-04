/// Problems found at start-up that screens need to know about.
class AppHealth {
  AppHealth._();

  /// True when the scan database could not be opened, so scans are kept in
  /// memory only and will be lost when the app closes.
  static bool databaseFailed = false;

  /// So the warning is shown only once per app start.
  static bool warningShown = false;

  static void reset() {
    databaseFailed = false;
    warningShown = false;
  }
}

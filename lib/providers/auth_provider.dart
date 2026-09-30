import 'package:flutter/foundation.dart';

/// Where the user is in the login flow.
enum AuthStatus {
  unknown, // app just started, still checking for a saved session
  signedOut,
  awaitingCode, // password OK, waiting for the emailed 2FA code
  signedIn,
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  String? _userId;
  String? _username;
  String? _email;

  AuthStatus get status => _status;
  String? get userId => _userId;
  String? get username => _username;
  String? get email => _email;
  bool get isSignedIn => _status == AuthStatus.signedIn;

  // Parts 4-7 will add: register(), login(), verifyCode(), logout(), ...
  // For now this only lets other parts of the app compile and be tested.
  @visibleForTesting
  void debugSetStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}

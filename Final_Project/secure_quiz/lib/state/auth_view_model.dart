import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({AuthService? authService})
    : _authService = authService ?? const AuthService();

  final AuthService _authService;

  bool _isLoginLoading = false;
  bool _isSignupLoading = false;

  bool get isLoginLoading => _isLoginLoading;
  bool get isSignupLoading => _isSignupLoading;

  Future<AppRole> login({
    required String email,
    required String password,
  }) async {
    _setLoginLoading(true);
    try {
      await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );
      final role = await _authService.getRoleForUser(forceRefreshToken: true);
      if (role == AppRole.unknown) {
        await _authService.signOut();
      }
      return role;
    } finally {
      _setLoginLoading(false);
    }
  }

  Future<void> signup({
    required String email,
    required String password,
    required AppRole role,
    required String displayName,
    String? studentBatch,
  }) async {
    _setSignupLoading(true);
    try {
      await _authService.signUpWithEmailPassword(
        email: email,
        password: password,
        role: role,
        displayName: displayName,
        studentBatch: studentBatch,
      );
    } on FirebaseAuthException {
      rethrow;
    } finally {
      _setSignupLoading(false);
    }
  }

  void _setLoginLoading(bool value) {
    if (_isLoginLoading == value) {
      return;
    }
    _isLoginLoading = value;
    notifyListeners();
  }

  void _setSignupLoading(bool value) {
    if (_isSignupLoading == value) {
      return;
    }
    _isSignupLoading = value;
    notifyListeners();
  }
}

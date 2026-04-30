import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_role.dart';

class AuthService {
  const AuthService();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmailPassword({
    required String email,
    required String password,
    required AppRole role,
    String? displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    if ((displayName ?? '').trim().isNotEmpty) {
      await credential.user?.updateDisplayName(displayName!.trim());
    }

    await _db.collection('users').doc(credential.user!.uid).set({
      'email': email.trim().toLowerCase(),
      'role': role.firestoreValue,
      'displayName': (displayName ?? '').trim(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return credential;
  }

  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() => _auth.signOut();

  Future<AppRole> getRoleForUser({
    String? uid,
    bool forceRefreshToken = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      return AppRole.unknown;
    }

    if (uid != null && uid != user.uid) {
      return AppRole.unknown;
    }

    DocumentSnapshot<Map<String, dynamic>>? profileDoc;
    try {
      // Prefer fresh role from server to avoid stale local cache.
      profileDoc = await _db
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      // Fallback to cache if server is temporarily unavailable.
      profileDoc = await _db.collection('users').doc(user.uid).get();
    }

    final firestoreRole = appRoleFromDynamic(profileDoc.data()?['role']);
    if (firestoreRole != AppRole.unknown) {
      return firestoreRole;
    }

    try {
      final tokenResult = await user.getIdTokenResult(forceRefreshToken);
      final claimRole = appRoleFromDynamic(tokenResult.claims?['role']);
      if (claimRole != AppRole.unknown) {
        return claimRole;
      }
    } catch (_) {
      // Ignore claim parsing errors.
    }

    return AppRole.unknown;
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_role.dart';

class AuthService {
  const AuthService();

  static const int _signupRoleReadRetries = 8;
  static const Duration _signupRoleReadRetryDelay = Duration(milliseconds: 250);

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
    String? studentBatch,
  }) async {
    final batchLabel = (studentBatch ?? '').trim();
    final normalizedBatch = _normalizeBatch(batchLabel);
    if (role == AppRole.student && normalizedBatch.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-batch',
        message: 'Batch is required for student accounts.',
      );
    }

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
      'batch': role == AppRole.student ? normalizedBatch : '',
      'batchLabel': role == AppRole.student ? batchLabel : '',
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Auth state changes are emitted immediately after createUser.
    // Confirm role can be read so bootstrap routing does not see a transient
    // "unknown" role on first load.
    await _waitForPersistedRole(
      userId: credential.user!.uid,
      expectedRole: role,
    );

    return credential;
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

    final isRecentAccount =
        user.metadata.creationTime != null &&
        DateTime.now().difference(user.metadata.creationTime!).inSeconds < 30;
    final maxAttempts = (forceRefreshToken || isRecentAccount)
        ? _signupRoleReadRetries
        : 1;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final firestoreRole = await _readRoleFromUserDocument(user.uid);
      if (firestoreRole != AppRole.unknown) {
        return firestoreRole;
      }

      final claimRole = await _readRoleFromClaims(
        user,
        forceRefreshToken: forceRefreshToken && attempt == 0,
      );
      if (claimRole != AppRole.unknown) {
        return claimRole;
      }

      if (attempt < maxAttempts - 1) {
        await Future<void>.delayed(_signupRoleReadRetryDelay);
      }
    }

    return AppRole.unknown;
  }

  Future<String> getStudentBatch({String? uid}) async {
    final user = _auth.currentUser;
    if (user == null) {
      return '';
    }

    if (uid != null && uid != user.uid) {
      return '';
    }

    DocumentSnapshot<Map<String, dynamic>> profileDoc;
    try {
      profileDoc = await _db
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      profileDoc = await _db.collection('users').doc(user.uid).get();
    }

    final rawBatch = (profileDoc.data()?['batch'] as String?) ?? '';
    return _normalizeBatch(rawBatch);
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  Future<AppRole> _readRoleFromUserDocument(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> profileDoc;
    try {
      profileDoc = await _db
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
    } on FirebaseException {
      profileDoc = await _db.collection('users').doc(uid).get();
    }
    return appRoleFromDynamic(profileDoc.data()?['role']);
  }

  Future<AppRole> _readRoleFromClaims(
    User user, {
    required bool forceRefreshToken,
  }) async {
    try {
      final tokenResult = await user.getIdTokenResult(forceRefreshToken);
      return appRoleFromDynamic(tokenResult.claims?['role']);
    } catch (_) {
      return AppRole.unknown;
    }
  }

  Future<void> _waitForPersistedRole({
    required String userId,
    required AppRole expectedRole,
  }) async {
    for (var attempt = 0; attempt < _signupRoleReadRetries; attempt++) {
      final role = await _readRoleFromUserDocument(userId);
      if (role == expectedRole) {
        return;
      }
      await Future<void>.delayed(_signupRoleReadRetryDelay);
    }
  }

  String _normalizeBatch(String? input) {
    return (input ?? '').trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }
}

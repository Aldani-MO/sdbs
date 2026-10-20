import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service layer for all authentication operations.
/// Encapsulates Firebase Auth + Firestore user document creation
/// so that UI widgets never directly call Firebase APIs.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// The currently signed-in user (null if not logged in).
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes (login / logout).
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with email and password.
  /// Returns the user's Firestore role ('Passenger', 'Driver', 'Admin').
  Future<String> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    if (credential.user == null) {
      throw Exception('Login failed — no user returned.');
    }

    // Fetch role from Firestore
    final doc =
        await _db.collection('users').doc(credential.user!.uid).get();
    if (!doc.exists) return 'Passenger'; // safe fallback
    return (doc.data()?['role'] as String?) ?? 'Passenger';
  }

  /// Register a new passenger account.
  Future<void> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    await _db
        .collection('users')
        .doc(credential.user!.uid)
        .set({
          'firstName': firstName.trim(),
          'lastName': lastName.trim(),
          'phone': phone.trim(),
          'email': email.trim(),
          'role': 'Passenger',
          'balance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(const Duration(seconds: 10),
            onTimeout: () =>
                throw Exception('Firestore connection timed out.'));
  }

  /// Change the current user's password (requires re-authentication).
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(newPassword);
  }

  /// Sign out the current user.
  Future<void> signOut() => _auth.signOut();

  // ── Admin User Management ──────────────────────────────────────

  /// Check if an email is already registered in the `users` collection.
  Future<bool> emailAlreadyRegistered(String email) async {
    final query = await _db
        .collection('users')
        .where('email', isEqualTo: email.trim())
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Admin-only: create a new user account without logging out the admin.
  /// Uses the Secondary Firebase App trick to isolate the new Auth session.
  Future<void> createUserByAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String role,
  }) async {
    // Import firebase_core inline to avoid polluting non-admin code
    // ignore: depend_on_referenced_packages
    final FirebaseApp secondaryApp = await Firebase.initializeApp(
      name: 'SecondaryApp',
      options: FirebaseAuth.instance.app.options,
    );

    try {
      final cred = await FirebaseAuth.instanceFor(app: secondaryApp)
          .createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      await _db.collection('users').doc(cred.user!.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role,
        'balance': 0.0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Admin-only: change the role of an existing user.
  Future<void> updateUserRole(String userId, String newRole) async {
    await _db.collection('users').doc(userId).update({'role': newRole});
  }
}

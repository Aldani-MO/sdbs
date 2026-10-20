import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Global user state provider.
/// Tracks the current user's profile data (name, role, balance) and
/// exposes it to all widgets via `Provider.of<UserProvider>(context)`.
class UserProvider extends ChangeNotifier {
  String _uid = '';
  String _firstName = '';
  String _lastName = '';
  String _email = '';
  String _phone = '';
  String _role = 'Passenger';
  double _balance = 0.0;
  bool _isLoading = true;

  // ── Getters ────────────────────────────────────────────────────
  String get uid => _uid;
  String get firstName => _firstName;
  String get lastName => _lastName;
  String get fullName => '$_firstName $_lastName'.trim();
  String get email => _email;
  String get phone => _phone;
  String get role => _role;
  double get balance => _balance;
  bool get isLoading => _isLoading;

  bool get isAdmin => _role == 'Admin';
  bool get isDriver => _role == 'Driver';
  bool get isPassenger => _role == 'Passenger';

  /// Load the user profile from Firestore after login.
  Future<void> loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _uid = user.uid;
    _email = user.email ?? '';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        _firstName = data['firstName'] ?? '';
        _lastName = data['lastName'] ?? '';
        _phone = data['phone'] ?? '';
        _role = data['role'] ?? 'Passenger';
        _balance = (data['balance'] ?? 0.0).toDouble();
      }
    } catch (e) {
      debugPrint('[UserProvider] Error loading user: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Clear all local state on sign-out.
  void clear() {
    _uid = '';
    _firstName = '';
    _lastName = '';
    _email = '';
    _phone = '';
    _role = 'Passenger';
    _balance = 0.0;
    _isLoading = true;
    notifyListeners();
  }
}

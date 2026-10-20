import 'package:flutter_test/flutter_test.dart';

/// Unit tests for UserProvider state management
/// Tests the provider's getters, role checks, and state manipulation
/// This mirrors providers/user_provider.dart logic

// ── Simplified UserProvider for testing (no Firebase dependency) ──
class UserProvider {
  String? _uid;
  String? _firstName;
  String? _lastName;
  String? _email;
  String? _phone;
  String? _role;
  double _balance = 0.0;
  bool _isLoading = false;

  // Getters
  String? get uid => _uid;
  String? get firstName => _firstName;
  String? get lastName => _lastName;
  String? get email => _email;
  String? get phone => _phone;
  String? get role => _role;
  double get balance => _balance;
  bool get isLoading => _isLoading;

  String get fullName => '${_firstName ?? ''} ${_lastName ?? ''}'.trim();
  bool get isAdmin => _role == 'Admin';
  bool get isDriver => _role == 'Driver';
  bool get isPassenger => _role == 'Passenger';

  void setUser({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
    required double balance,
  }) {
    _uid = uid;
    _firstName = firstName;
    _lastName = lastName;
    _email = email;
    _phone = phone;
    _role = role;
    _balance = balance;
  }

  void clear() {
    _uid = null;
    _firstName = null;
    _lastName = null;
    _email = null;
    _phone = null;
    _role = null;
    _balance = 0.0;
    _isLoading = false;
  }
}

void main() {
  group('UserProvider - Initial State', () {
    test('Should have null values initially', () {
      final provider = UserProvider();
      expect(provider.uid, isNull);
      expect(provider.firstName, isNull);
      expect(provider.lastName, isNull);
      expect(provider.email, isNull);
      expect(provider.role, isNull);
    });

    test('Should have zero balance initially', () {
      final provider = UserProvider();
      expect(provider.balance, equals(0.0));
    });

    test('Should not be loading initially', () {
      final provider = UserProvider();
      expect(provider.isLoading, isFalse);
    });

    test('Should not be any role initially', () {
      final provider = UserProvider();
      expect(provider.isAdmin, isFalse);
      expect(provider.isDriver, isFalse);
      expect(provider.isPassenger, isFalse);
    });
  });

  group('UserProvider - Set User Data', () {
    test('Should set all fields correctly', () {
      final provider = UserProvider();
      provider.setUser(
        uid: 'uid123', firstName: 'Ahmad', lastName: 'Assaf',
        email: 'ahmad@test.com', phone: '0791234567',
        role: 'Passenger', balance: 10.0,
      );
      expect(provider.uid, equals('uid123'));
      expect(provider.firstName, equals('Ahmad'));
      expect(provider.lastName, equals('Assaf'));
      expect(provider.email, equals('ahmad@test.com'));
      expect(provider.phone, equals('0791234567'));
      expect(provider.role, equals('Passenger'));
      expect(provider.balance, equals(10.0));
    });

    test('Should compute fullName correctly', () {
      final provider = UserProvider();
      provider.setUser(
        uid: 'u1', firstName: 'Jack', lastName: 'Zeidan',
        email: 'j@t.com', phone: '079', role: 'Driver', balance: 0,
      );
      expect(provider.fullName, equals('Jack Zeidan'));
    });
  });

  group('UserProvider - Role Checks', () {
    test('Should identify Admin role', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'M', lastName: 'A',
          email: 'a@b.com', phone: '079', role: 'Admin', balance: 0);
      expect(provider.isAdmin, isTrue);
      expect(provider.isDriver, isFalse);
      expect(provider.isPassenger, isFalse);
    });

    test('Should identify Driver role', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'M', lastName: 'A',
          email: 'a@b.com', phone: '079', role: 'Driver', balance: 0);
      expect(provider.isDriver, isTrue);
      expect(provider.isAdmin, isFalse);
      expect(provider.isPassenger, isFalse);
    });

    test('Should identify Passenger role', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'M', lastName: 'A',
          email: 'a@b.com', phone: '079', role: 'Passenger', balance: 0);
      expect(provider.isPassenger, isTrue);
      expect(provider.isAdmin, isFalse);
      expect(provider.isDriver, isFalse);
    });
  });

  group('UserProvider - Clear', () {
    test('Should reset all fields to initial state', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'Test', lastName: 'User',
          email: 't@t.com', phone: '079', role: 'Admin', balance: 50.0);
      provider.clear();
      expect(provider.uid, isNull);
      expect(provider.firstName, isNull);
      expect(provider.balance, equals(0.0));
      expect(provider.isAdmin, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('Should allow re-setting user after clear', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'A', lastName: 'B',
          email: 'a@b.com', phone: '079', role: 'Admin', balance: 10);
      provider.clear();
      provider.setUser(uid: 'u2', firstName: 'C', lastName: 'D',
          email: 'c@d.com', phone: '078', role: 'Driver', balance: 20);
      expect(provider.uid, equals('u2'));
      expect(provider.firstName, equals('C'));
      expect(provider.isDriver, isTrue);
      expect(provider.balance, equals(20));
    });
  });

  group('UserProvider - Edge Cases', () {
    test('Should handle empty names in fullName', () {
      final provider = UserProvider();
      expect(provider.fullName, equals(''));
    });

    test('Should handle balance of 0', () {
      final provider = UserProvider();
      provider.setUser(uid: 'u1', firstName: 'A', lastName: 'B',
          email: 'a@b.com', phone: '079', role: 'Passenger', balance: 0.0);
      expect(provider.balance, equals(0.0));
    });
  });
}

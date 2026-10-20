import 'package:cloud_firestore/cloud_firestore.dart';

/// Service layer for all wallet / balance / transaction operations.
/// Extracts Firestore logic from cards.dart and home.dart.
class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of the user's profile document (includes balance).
  Stream<DocumentSnapshot> userProfileStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  /// Top up the user's wallet balance and record the transaction.
  Future<void> topUp(String uid, double amount) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive.');

    // Atomic increment — safe even with concurrent writes
    await _db.collection('users').doc(uid).update({
      'balance': FieldValue.increment(amount),
    });

    // Record the transaction for history
    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
      'type': 'topup',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Deduct a fare from the user's wallet (future: auto-deduct on check-in).
  Future<void> deductFare(String uid, double amount) async {
    if (amount <= 0) throw ArgumentError('Amount must be positive.');

    await _db.collection('users').doc(uid).update({
      'balance': FieldValue.increment(-amount),
    });

    await _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .add({
      'type': 'fare',
      'amount': amount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Stream of recent transactions for a user (last 10).
  Stream<QuerySnapshot> transactionsStream(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('transactions')
      .orderBy('timestamp', descending: true)
      .limit(10)
      .snapshots();
}

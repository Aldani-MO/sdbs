import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service layer for the SDBS Decision Engine (PRD Section 5).
///
/// Centralizes all business logic for determining bus stop actions
/// (STOP / SKIP / EARLY DEPART) and persisting audit logs to Firestore.
/// The Driver Dashboard UI simply calls these methods — it has zero
/// knowledge of Firestore or the decision algorithm itself.
class DecisionService {
  final FirebaseFirestore _db;

  DecisionService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ── Action Constants ───────────────────────────────────────────
  static const String actionStop = 'STOP';
  static const String actionSkip = 'SKIP';
  static const String actionEarly = 'EARLY DEPART';

  // ── Decision Engine ────────────────────────────────────────────

  /// PRD §5 — Capacity-Aware Decision Engine.
  ///
  /// Balances passenger demand (waiting) with available bus supply (capacity).
  /// Priority order (first matching rule wins):
  ///
  ///   1. [waitingCount] == 0
  ///      → SKIP  (no one waiting — skip to save time)
  ///
  ///   2. [occupancy] >= [busCapacity]  (bus is full)
  ///      → SKIP  (physically cannot board anyone, notify waiting passengers)
  ///
  ///   3. [waitingCount] > availableSeats  (demand exceeds supply)
  ///      → STOP  (must stop, but warn passengers not all can board)
  ///
  ///   4. [waitingCount] >= [maxThreshold] AND space available
  ///      → EARLY DEPART  (high demand + bus has room — rush to pick them up)
  ///
  ///   5. Fallback
  ///      → STOP  (normal stop, passengers waiting and space available)
  ///
  /// [busCapacity] defaults to 50 if not provided (backward compatible).
  /// Returns a [DecisionResult] with action and reason strings.
  static DecisionResult calculateDecision({
    required int waitingCount,
    required int occupancy,
    required int maxThreshold,
    int busCapacity = 50,
  }) {
    final int availableSeats = (busCapacity - occupancy).clamp(0, busCapacity);

    // Rule 1: No one waiting → skip
    if (waitingCount == 0) {
      return DecisionResult(
        action: actionSkip,
        reason: 'No passengers waiting',
      );
    }

    // Rule 2: Bus is at full capacity → skip (can't board anyone)
    if (occupancy >= busCapacity) {
      return DecisionResult(
        action: actionSkip,
        reason: 'Bus full — cannot board passengers',
      );
    }

    // Rule 3: More people waiting than available seats → stop, but warn
    if (waitingCount > availableSeats) {
      return DecisionResult(
        action: actionStop,
        reason: 'Limited space — not all may board ($availableSeats seats left)',
      );
    }

    // Rule 4: High demand AND sufficient space → early depart to serve them fast
    if (waitingCount >= maxThreshold) {
      return DecisionResult(
        action: actionEarly,
        reason: 'High demand — depart early ($availableSeats seats available)',
      );
    }

    // Rule 5: Normal stop
    return DecisionResult(
      action: actionStop,
      reason: 'Passengers waiting',
    );
  }

  // ── Audit Logging (DE-05) ──────────────────────────────────────

  /// Persist a stop decision to the `stopDecisions` collection.
  /// Uses a deduplication key so the same decision is never logged twice
  /// (important because StreamBuilder rebuilds many times).
  Future<void> logDecision({
    required String stopId,
    required String stopName,
    required String tripId,
    required String busId,
    required String action,
    required String reason,
    required int waitingCount,
    required int occupancy,
    required Set<String> logged, // pass the widget's _loggedDecisions Set
  }) async {
    final key = '${tripId}_${stopId}_$action';
    if (logged.contains(key)) return;
    logged.add(key);

    try {
      await _db.collection('stopDecisions').add({
        'action': action,
        'reason': reason,
        'stopId': stopId,
        'stopName': stopName,
        'tripId': tripId,
        'busId': busId,
        'waitingCount': waitingCount,
        'occupancy': occupancy,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Non-critical — log and continue
      // ignore: avoid_print
      debugPrint('[DecisionService] Log error: $e');
    }
  }

  // ── Passenger Notifications (DP-01) ───────────────────────────

  /// Notify all passengers checked in at [stopId] for [tripId]
  /// when the decision is SKIP or EARLY DEPART.
  ///
  /// Uses a Firestore batch write for atomicity and deduplication
  /// via [notified] Set to prevent repeat notifications.
  Future<void> sendPassengerNotifications({
    required String stopId,
    required String stopName,
    required String tripId,
    required String busId,
    required String action,
    required Set<String> notified, // pass the widget's _notifiedDecisions Set
  }) async {
    if (action == actionStop) return; // No notification needed for STOP

    final key = '${tripId}_${stopId}_$action';
    if (notified.contains(key)) return;
    notified.add(key);

    try {
      // Find all passengers checked in at this stop for this trip
      final checkIns = await _db
          .collection('checkIns')
          .where('tripID', isEqualTo: tripId)
          .where('stopID', isEqualTo: stopId)
          .get();

      if (checkIns.docs.isEmpty) return;

      // Build message based on action type
      final String title;
      final String description;
      final String type;

      if (action == actionSkip) {
        title = '⚠️ Bus Skipping Your Stop';
        description =
            '$busId is skipping $stopName. The bus may be full or no passengers '
            'are waiting. Please wait for the next available bus.';
        type = 'skip';
      } else {
        // EARLY DEPART
        title = '🚌 Bus Departing Early!';
        description =
            '$busId is departing early from $stopName due to high demand and '
            'available capacity. Please hurry to the stop!';
        type = 'delay';
      }

      // Batch write one notification per unique passenger
      final batch = _db.batch();
      final Set<String> notifiedUsers = {};

      for (final doc in checkIns.docs) {
        final data = doc.data();
        final passengerId = data['passengerID']?.toString() ?? '';
        if (passengerId.isEmpty || notifiedUsers.contains(passengerId)) {
          continue;
        }
        notifiedUsers.add(passengerId);

        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'userId': passengerId,
          'title': title,
          'description': description,
          'type': type,
          'tripId': tripId,
          'busId': busId,
          'stopId': stopId,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
      }

      await batch.commit();
    } catch (e) {
      // ignore: avoid_print
      debugPrint('[DecisionService] Notification error: $e');
    }
  }
}

/// Value object returned by [DecisionService.calculateDecision].
class DecisionResult {
  final String action;
  final String reason;

  const DecisionResult({required this.action, required this.reason});
}

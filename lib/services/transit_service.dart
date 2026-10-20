import 'package:cloud_firestore/cloud_firestore.dart';

/// Service layer for all transit-related Firestore operations.
/// Handles stops, routes, trips, check-ins, and decision logging.
class TransitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Stops ──────────────────────────────────────────────────────

  /// Stream of all stops (real-time updates).
  Stream<QuerySnapshot> stopsStream() => _db.collection('stops').snapshots();

  /// Check if a stop ID already exists.
  Future<bool> stopExists(String stopId) async {
    final doc = await _db.collection('stops').doc(stopId).get();
    return doc.exists;
  }

  /// Check if a stop name already exists.
  Future<bool> stopNameExists(String name) async {
    final query = await _db
        .collection('stops')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    return query.docs.isNotEmpty;
  }

  /// Create a new stop document.
  Future<void> createStop({
    required String stopId,
    required String name,
    required double latitude,
    required double longitude,
    required int maxThreshold,
  }) async {
    await _db.collection('stops').doc(stopId).set({
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'maxThreshold': maxThreshold,
    });
  }

  /// Delete a stop. Prevents deletion if the stop is used in any route.
  Future<void> deleteStop(String stopId) async {
    final routes = await _db.collection('routes').get();
    for (final doc in routes.docs) {
      final stopIds = (doc.data()['stopIds'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList();
      if (stopIds.contains(stopId)) {
        final routeName = doc.data()['name'] ?? doc.id;
        throw Exception('Cannot delete: this stop is used in route "$routeName".');
      }
    }
    await _db.collection('stops').doc(stopId).delete();
  }

  // ── Routes ─────────────────────────────────────────────────────

  /// Stream of active routes.
  Stream<QuerySnapshot> activeRoutesStream() =>
      _db.collection('routes').where('isActive', isEqualTo: true).snapshots();

  /// Stream of all routes (for admin).
  Stream<QuerySnapshot> allRoutesStream() =>
      _db.collection('routes').snapshots();

  /// Get a single route document.
  Future<DocumentSnapshot> getRoute(String routeId) =>
      _db.collection('routes').doc(routeId).get();

  // ── Trips ──────────────────────────────────────────────────────

  /// Stream of active trips for a specific driver.
  Stream<QuerySnapshot> driverTripsStream(String driverId) => _db
      .collection('trips')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'Active')
      .snapshots();

  /// Stream of a single trip document.
  Stream<DocumentSnapshot> tripStream(String tripId) =>
      _db.collection('trips').doc(tripId).snapshots();

  // ── Check-Ins ──────────────────────────────────────────────────

  /// Stream of check-ins for a specific trip.
  Stream<QuerySnapshot> checkInsForTrip(String tripId) =>
      _db.collection('checkIns').where('tripID', isEqualTo: tripId).snapshots();

  /// Stream of check-ins for a specific passenger.
  Stream<QuerySnapshot> checkInsForPassenger(String passengerId) => _db
      .collection('checkIns')
      .where('passengerID', isEqualTo: passengerId)
      .snapshots();

  // ── Buses ──────────────────────────────────────────────────────

  /// Stream of a single bus document (occupancy updates).
  Stream<DocumentSnapshot> busStream(String busId) =>
      _db.collection('buses').doc(busId).snapshots();

  // ── Decision Logging ───────────────────────────────────────────

  /// Log a stop decision to the stopDecisions collection (DE-05).
  Future<void> logStopDecision({
    required String stopId,
    required String stopName,
    required String tripId,
    required String busId,
    required String action,
    required String reason,
    required int waitingCount,
    required int occupancy,
  }) async {
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
  }

  // ── Notifications ──────────────────────────────────────────────

  /// Send a notification to a specific user.
  Future<void> sendNotification({
    required String userId,
    required String title,
    required String description,
    required String type,
    required String tripId,
    required String busId,
    required String stopId,
  }) async {
    await _db.collection('notifications').add({
      'userId': userId,
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

  // ── Check-In (Passenger-facing) ────────────────────────────────

  /// Load the stop name and all active trips passing through [stopId].
  /// Extracted from stop_trip_picker.dart — UI only receives the result.
  Future<CheckInContext> loadTripsAtStop(String stopId) async {
    // 1. Get stop name
    final stopDoc = await _db.collection('stops').doc(stopId).get();
    final stopName = stopDoc.exists
        ? (stopDoc.data() as Map<String, dynamic>)['name'] ?? 'Stop $stopId'
        : 'Unknown Stop ($stopId)';

    // 2. Find all routes that contain this stopId
    final allRoutes = await _db.collection('routes').get();
    final matchingRouteIds = <String>[];

    for (final routeDoc in allRoutes.docs) {
      final stopIds = ((routeDoc.data()['stopIds'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList();
      if (stopIds.contains(stopId)) {
        matchingRouteIds.add(routeDoc.id);
      }
    }

    if (matchingRouteIds.isEmpty) {
      return CheckInContext(stopName: stopName, trips: []);
    }

    // 3. Find all ACTIVE trips for those routes, with route name
    final trips = <Map<String, dynamic>>[];
    for (final routeId in matchingRouteIds) {
      final tripQuery = await _db
          .collection('trips')
          .where('routeId', isEqualTo: routeId)
          .where('status', isEqualTo: 'Active')
          .get();

      final routeDoc = await _db.collection('routes').doc(routeId).get();
      final routeName = routeDoc.exists
          ? (routeDoc.data() as Map<String, dynamic>)['name'] ?? routeId
          : routeId;

      for (final tripDoc in tripQuery.docs) {
        final tData = tripDoc.data();
        trips.add({
          'tripId': tripDoc.id,
          'busId': (tData['busId'] ?? 'Bus').toString().toUpperCase(),
          'routeId': routeId,
          'routeName': routeName,
          'driverId': tData['driverId'] ?? '',
        });
      }
    }
    return CheckInContext(stopName: stopName, trips: trips);
  }

  /// Record a passenger check-in for [tripId] at [stopId].
  /// Extracted from stop_trip_picker.dart — throws on failure.
  Future<void> processCheckIn({
    required String passengerId,
    required String stopId,
    required String tripId,
  }) async {
    // 1. Check if user is already checked in for this trip
    final existingCheckIn = await _db
        .collection('checkIns')
        .where('passengerID', isEqualTo: passengerId)
        .where('tripID', isEqualTo: tripId)
        .get();

    if (existingCheckIn.docs.isNotEmpty) {
      final existingDoc = existingCheckIn.docs.first;
      final existingData = existingDoc.data();
      
      if (existingData['stopID'] == stopId) {
        throw Exception('You are already checked in at this stop for this trip.');
      } else {
        // Edge case: Passenger walked to another stop and scanned there.
        // Update their boarding location instead of creating a duplicate.
        await existingDoc.reference.update({
          'stopID': stopId,
          'timeStamp': FieldValue.serverTimestamp(),
        });
        return; // Successfully updated, exit early
      }
    }

    // 2. Process check-in
    await _db.collection('checkIns').add({
      'timeStamp': FieldValue.serverTimestamp(),
      'passengerCount': 1,
      'passengerID': passengerId,
      'stopID': stopId,
      'tripID': tripId,
    });
  }

  // ── Routes ─────────────────────────────────────────────────────

  /// Fetch all stops once (for route builder dropdowns).
  Future<List<Map<String, dynamic>>> fetchAllStops() async {
    final snap = await _db.collection('stops').get();
    return snap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  /// Check if a route ID already exists.
  Future<bool> routeExists(String routeId) async {
    final doc = await _db.collection('routes').doc(routeId).get();
    return doc.exists;
  }

  /// Check if a route name already exists.
  Future<bool> routeNameExists(String name) async {
    final q = await _db
        .collection('routes')
        .where('name', isEqualTo: name)
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Create a new route document.
  Future<void> createRoute({
    required String routeId,
    required String name,
    required bool isActive,
    required List<String> stopIds,
  }) async {
    await _db.collection('routes').doc(routeId).set({
      'name': name,
      'isActive': isActive,
      'stopIds': stopIds,
    });
  }

  /// Update an existing route document.
  Future<void> updateRoute({
    required String routeId,
    required String name,
    required bool isActive,
    required List<String> stopIds,
  }) async {
    await _db.collection('routes').doc(routeId).update({
      'name': name,
      'isActive': isActive,
      'stopIds': stopIds,
    });
  }

  /// Toggle a route's active status.
  Future<void> toggleRouteActive(String routeId, bool isActive) async {
    await _db.collection('routes').doc(routeId).update({'isActive': isActive});
  }

  /// Delete a route. Prevents deletion if the route has active trips.
  Future<void> deleteRoute(String routeId) async {
    final activeTrips = await _db
        .collection('trips')
        .where('routeId', isEqualTo: routeId)
        .where('status', isEqualTo: 'Active')
        .limit(1)
        .get();

    if (activeTrips.docs.isNotEmpty) {
      throw Exception('Cannot delete a route that has active trips.');
    }
    await _db.collection('routes').doc(routeId).delete();
  }

  /// Stream of all routes (real-time).
  Stream<QuerySnapshot> routesStream() => _db.collection('routes').snapshots();

  // ── Trips ──────────────────────────────────────────────────────

  /// Check if a driver already has an active trip.
  Future<bool> driverHasActiveTrip(String driverId) async {
    final q = await _db
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'Active')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Check if a bus is already on an active trip.
  Future<bool> busHasActiveTrip(String busId) async {
    final q = await _db
        .collection('trips')
        .where('busId', isEqualTo: busId)
        .where('status', isEqualTo: 'Active')
        .limit(1)
        .get();
    return q.docs.isNotEmpty;
  }

  /// Check if a route is currently active.
  Future<bool> routeIsActive(String routeId) async {
    final doc = await _db.collection('routes').doc(routeId).get();
    if (!doc.exists) return false;
    return (doc.data()?['isActive'] ?? false) == true;
  }

  /// Create a new trip.
  Future<void> createTrip({
    required String busId,
    required String routeId,
    required String driverId,
  }) async {
    await _db.collection('trips').add({
      'busId': busId,
      'routeId': routeId,
      'driverId': driverId,
      'status': 'Active',
      'startTime': FieldValue.serverTimestamp(),
    });
  }

  /// Clear all check-ins at a specific stop for a trip (passengers boarded).
  Future<void> clearCheckInsForStop(String tripId, String stopId) async {
    final snap = await _db
        .collection('checkIns')
        .where('tripID', isEqualTo: tripId)
        .where('stopID', isEqualTo: stopId)
        .get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  /// End (complete) a trip by ID. Also clears any remaining check-ins.
  Future<void> endTrip(String tripId) async {
    // Clear all remaining check-ins for this trip
    final snap = await _db
        .collection('checkIns')
        .where('tripID', isEqualTo: tripId)
        .get();
    final batch = _db.batch();
    for (var doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    await _db.collection('trips').doc(tripId).update({'status': 'Completed'});
  }

  /// Stream of all active trips.
  Stream<QuerySnapshot> activeTripsStream() =>
      _db.collection('trips').where('status', isEqualTo: 'Active').snapshots();

  /// Stream of drivers (users with role == Driver).
  Stream<QuerySnapshot> driversStream() =>
      _db.collection('users').where('role', isEqualTo: 'Driver').snapshots();

  // ── Notifications (Passenger-facing reads) ─────────────────────

  /// Stream of notifications for a specific user.
  Stream<QuerySnapshot> notificationsStream(String userId) => _db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .snapshots();

  /// Stream of unread notifications for a specific user.
  Stream<QuerySnapshot> unreadNotificationsStream(String userId) => _db
      .collection('notifications')
      .where('userId', isEqualTo: userId)
      .where('read', isEqualTo: false)
      .snapshots();

  /// Mark all unread notifications as read in a single batch.
  Future<void> markAllNotificationsRead(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final batch = _db.batch();
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['read'] != true) {
        batch.update(doc.reference, {'read': true});
      }
    }
    await batch.commit();
  }

  /// Mark a single notification as read.
  Future<void> markNotificationRead(DocumentReference ref) async {
    await ref.update({'read': true});
  }
}

/// Value object returned by [TransitService.loadTripsAtStop].
class CheckInContext {
  final String stopName;
  final List<Map<String, dynamic>> trips;
  const CheckInContext({required this.stopName, required this.trips});
}

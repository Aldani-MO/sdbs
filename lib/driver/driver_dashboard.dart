import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth/login.dart';
import '../services/auth_service.dart';
import '../services/decision_service.dart';
import '../services/transit_service.dart';

class DriverDashboardPage extends StatefulWidget {
  const DriverDashboardPage({super.key});

  @override
  State<DriverDashboardPage> createState() => _DriverDashboardPageState();
}

class _DriverDashboardPageState extends State<DriverDashboardPage> {
  final Color greenColor = const Color(0xFF4CAF50);
  final Color yellowColor = const Color(0xFFFFC107);
  final Color redColor = const Color(0xFFE91E63);

  /// DR-01: Currently selected trip (null = show selection screen)
  String? _selectedTripId;
  int _currentStopIndex = 0;

  /// Track which (stopId + action) combos have already been notified
  /// so we don't spam passengers on every StreamBuilder rebuild.
  final Set<String> _notifiedDecisions = {};
  final Set<String> _loggedDecisions = {};

  /// PRD §5 — Decision Engine (delegated to DecisionService).
  DecisionResult _decide(int waitingCount, int occupancy, int maxThreshold, [int busCapacity = 50]) {
    return DecisionService.calculateDecision(
      waitingCount: waitingCount,
      occupancy: occupancy,
      maxThreshold: maxThreshold,
      busCapacity: busCapacity,
    );
  }

  /// DE-05 — Log decision (delegated to DecisionService).
  void _logDecision({
    required String stopId, required String stopName,
    required String tripId, required String busId,
    required String action, required String reason,
    required int waitingCount, required int occupancy,
  }) {
    Provider.of<DecisionService>(context, listen: false).logDecision(
      stopId: stopId, stopName: stopName, tripId: tripId, busId: busId,
      action: action, reason: reason,
      waitingCount: waitingCount, occupancy: occupancy,
      logged: _loggedDecisions,
    );
  }

  /// DP-01 — Notify passengers (delegated to DecisionService).
  void _notify({
    required String stopId, required String stopName,
    required String tripId, required String busId, required String action,
  }) {
    Provider.of<DecisionService>(context, listen: false).sendPassengerNotifications(
      stopId: stopId, stopName: stopName,
      tripId: tripId, busId: busId, action: action,
      notified: _notifiedDecisions,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Not logged in")));
    }

    // If driver already selected a trip, show it
    if (_selectedTripId != null) {
      return StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('trips').doc(_selectedTripId).snapshots(),
        builder: (context, snap) {
          // Wait for data — don't reset on initial loading state
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snap.hasData || !snap.data!.exists) {
            // Trip was deleted/ended externally
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTripId = null);
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final data = snap.data!.data() as Map<String, dynamic>;
          if (data['status'] != 'Active') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedTripId = null);
            });
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return _buildActiveTripScreen(_selectedTripId!, data['busId'] ?? 'Unknown', data['routeId'] ?? 'Unknown');
        },
      );
    }

    // DR-01: Show trip selection screen
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('trips')
          .where('driverId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'Active')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoTripsScreen();
        }

        // If only 1 trip, auto-select it
        if (snapshot.data!.docs.length == 1) {
          final tripDoc = snapshot.data!.docs.first;
          final tripData = tripDoc.data() as Map<String, dynamic>;
          return _buildActiveTripScreen(tripDoc.id, tripData['busId'] ?? 'Unknown', tripData['routeId'] ?? 'Unknown');
        }

        // Multiple trips — show selection screen
        return _buildTripSelectionScreen(snapshot.data!.docs);
      },
    );
  }

  Widget _buildNoTripsScreen() {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        title: const Text("Driver Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_bus_filled_outlined, size: 100, color: Colors.grey[400]),
            const SizedBox(height: 20),
            Text("No active trips assigned.", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey[500])),
            const SizedBox(height: 10),
            Text("Contact admin to assign you a trip.", style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  /// DR-01: Trip selection screen when driver has multiple assigned trips
  Widget _buildTripSelectionScreen(List<QueryDocumentSnapshot> trips) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        title: const Text("Select Your Trip", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your Assigned Trips", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Tap a trip to activate your dashboard", style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: trips.length,
                itemBuilder: (context, i) {
                  final trip = trips[i].data() as Map<String, dynamic>;
                  final busId = (trip['busId'] ?? '').toString().toUpperCase();
                  final routeId = trip['routeId'] ?? '';

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance.collection('routes').doc(routeId).get(),
                    builder: (context, routeSnap) {
                      String routeName = routeId;
                      if (routeSnap.hasData && routeSnap.data!.exists) {
                        routeName = (routeSnap.data!.data() as Map<String, dynamic>)['name'] ?? routeId;
                      }
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            setState(() {
                              _selectedTripId = trips[i].id;
                              _currentStopIndex = 0; // Reset when switching trips
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: AppTheme.maroon.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                                  child: Icon(Icons.directions_bus, color: AppTheme.maroon, size: 32),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(busId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                      const SizedBox(height: 4),
                                      Text(routeName, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: AppTheme.maroon, size: 28),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTripScreen(String tripId, String busId, String routeId) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: _buildAppBar(busId, routeId),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('routes').doc(routeId).get(),
        builder: (context, routeSnap) {
          if (!routeSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          List<String> stopIds = [];
          if (routeSnap.data!.exists) {
            final routeData = routeSnap.data!.data() as Map<String, dynamic>;
            final rawStopIds = routeData['stopIds'] as List<dynamic>? ?? [];
            stopIds = rawStopIds.map((e) => e.toString()).toList();
          }

          if (stopIds.isEmpty) {
            return const Center(child: Text("No stops assigned to this route."));
          }

          // Stream ALL checkIns for this trip in real-time
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('checkIns')
                .where('tripID', isEqualTo: tripId)
                .snapshots(),
            builder: (context, checkInSnap) {
              // Count waiting passengers per stop
              Map<String, int> waitingPerStop = {};
              if (checkInSnap.hasData) {
                for (var doc in checkInSnap.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stopID = data['stopID']?.toString() ?? '';
                  waitingPerStop[stopID] = (waitingPerStop[stopID] ?? 0) + ((data['passengerCount'] ?? 1) as num).toInt();
                }
              }

              // Ensure index is valid
              final safeIndex = _currentStopIndex < stopIds.length ? _currentStopIndex : 0;
              final currentStopId = stopIds[safeIndex];

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Next Stop Card with Decision
                  Expanded(
                    flex: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildNextStopCard(currentStopId, tripId, waitingPerStop, busId, stopIds),
                    ),
                  ),
                  // RIGHT: Upcoming Stops + Current Decision
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildRightPanel(stopIds, tripId, waitingPerStop, busId, currentStopId),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// Builds the big "Next Stop" card on the left with the real decision
  Widget _buildNextStopCard(String stopId, String tripId, Map<String, int> waitingPerStop, String busId, List<String> stopIds) {
    final int totalStops = stopIds.length;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('buses').doc(busId).snapshots(),
      builder: (context, busSnap) {
        final int liveOccupancy = (busSnap.hasData && busSnap.data!.exists)
            ? ((busSnap.data!.data() as Map<String, dynamic>)['currentOccupancy'] ?? 0) as int
            : 0;
        final int busCapacity = (busSnap.hasData && busSnap.data!.exists)
            ? ((busSnap.data!.data() as Map<String, dynamic>)['capacity'] ?? 50) as int
            : 50;

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('stops').doc(stopId).get(),
          builder: (context, stopSnap) {
            String stopName = "Loading...";
            int maxThreshold = 25;

            if (stopSnap.hasData && stopSnap.data!.exists) {
              final data = stopSnap.data!.data() as Map<String, dynamic>;
              stopName = data['name'] ?? 'Unknown';
              maxThreshold = (data['maxThreshold'] ?? 25).toInt();
            }

            final int waitingCount = waitingPerStop[stopId] ?? 0;
            final result = _decide(waitingCount, liveOccupancy, maxThreshold, busCapacity);
            final String decisionAction = result.action;
            final String decisionReason = result.reason;
            final Color decisionColor = decisionAction == DecisionService.actionStop
                ? greenColor
                : decisionAction == DecisionService.actionSkip
                    ? redColor
                    : yellowColor;

            // DE-05: Log every decision to stopDecisions collection
            _logDecision(
              stopId: stopId, stopName: stopName, tripId: tripId, busId: busId,
              action: decisionAction, reason: decisionReason,
              waitingCount: waitingCount, occupancy: liveOccupancy,
            );

            if (decisionAction == DecisionService.actionSkip || decisionAction == DecisionService.actionEarly) {
              _notify(
                stopId: stopId, stopName: stopName,
                tripId: tripId, busId: busId, action: decisionAction,
              );
            }

            return Container(
              decoration: BoxDecoration(color: decisionColor, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Stop ${_currentStopIndex + 1} of $totalStops", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.white, size: 40),
                      const SizedBox(width: 10),
                      Expanded(child: Text(stopName, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Decision Badge
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              decisionAction == DecisionService.actionStop ? Icons.check_circle_outline :
                              decisionAction == DecisionService.actionSkip ? Icons.skip_next :
                              Icons.warning_amber_rounded,
                              color: Colors.white, size: 40,
                            ),
                            const SizedBox(width: 10),
                            Text(decisionAction, style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(decisionReason, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Stats Row — Occupancy now reads live from Firebase
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem(Icons.person_outline, "Waiting", "$waitingCount", waitingCount > 0 ? Colors.orange : Colors.grey),
                        _buildStatItem(Icons.directions_bus_outlined, "Occupancy", "$liveOccupancy / $busCapacity", liveOccupancy > 0 ? Colors.blue : Colors.grey),
                        _buildStatItem(Icons.speed, "Threshold", "$maxThreshold", Colors.grey),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Navigation Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: decisionColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.location_on),
                        label: Text(
                          _currentStopIndex < totalStops - 1 ? "Arrived — Next Stop" : "Finish Trip",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final transit = Provider.of<TransitService>(context, listen: false);
                          // Clear check-ins for the current stop (passengers boarded)
                          final departingStopId = stopIds[_currentStopIndex];
                          await transit.clearCheckInsForStop(tripId, departingStopId);

                          if (_currentStopIndex < totalStops - 1) {
                            if (mounted) setState(() => _currentStopIndex++);
                          } else {
                            // Finish trip — endTrip also clears any remaining check-ins
                            await transit.endTrip(tripId);
                            if (mounted) {
                              setState(() {
                                _selectedTripId = null;
                                _currentStopIndex = 0;
                              });
                            }
                          }
                        },
                      ),
                      if (_currentStopIndex > 0)
                        TextButton(
                          onPressed: () => setState(() => _currentStopIndex--),
                          child: const Text("Previous Stop", style: TextStyle(color: Colors.white, decoration: TextDecoration.underline)),
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildStatItem(IconData icon, String label, String value, Color valueColor) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600], size: 28),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  /// Builds the right panel: upcoming stops list + CURRENT DECISION banner.
  /// Wraps in a bus stream to get live occupancy — same source as the left card.
  Widget _buildRightPanel(List<String> stopIds, String tripId, Map<String, int> waitingPerStop, String busId, String currentStopId) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('buses').doc(busId).snapshots(),
      builder: (context, busSnap) {
        // Live occupancy + capacity from bus document — consistent with left card
        final int liveOccupancy = (busSnap.hasData && busSnap.data!.exists)
            ? ((busSnap.data!.data() as Map<String, dynamic>)['currentOccupancy'] ?? 0) as int
            : 0;
        final int busCapacity = (busSnap.hasData && busSnap.data!.exists)
            ? ((busSnap.data!.data() as Map<String, dynamic>)['capacity'] ?? 50) as int
            : 50;

        return Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Route Progress", style: TextStyle(color: AppTheme.maroon, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.builder(
                        itemCount: stopIds.length - _currentStopIndex,
                        itemBuilder: (context, i) {
                          final actualIndex = _currentStopIndex + i;
                          final stopId = stopIds[actualIndex];
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('stops').doc(stopId).get(),
                            builder: (context, stopSnap) {
                              String name = 'Loading...';
                              int maxT = 25;
                              if (stopSnap.hasData && stopSnap.data!.exists) {
                                final data = stopSnap.data!.data() as Map<String, dynamic>;
                                name = data['name'] ?? 'Unknown';
                                maxT = (data['maxThreshold'] ?? 25).toInt();
                              }

                              final int waiting = waitingPerStop[stopId] ?? 0;
                              // Pass busCapacity so full-bus SKIP logic is applied
                              final result = _decide(waiting, liveOccupancy, maxT, busCapacity);
                              final action = result.action;
                              final Color badgeColor = action == DecisionService.actionStop
                                  ? greenColor
                                  : action == DecisionService.actionSkip
                                      ? redColor
                                      : yellowColor;

                              final bool isCurrent = actualIndex == _currentStopIndex;

                              if (action == DecisionService.actionSkip || action == DecisionService.actionEarly) {
                                _notify(
                                  stopId: stopId, stopName: name,
                                  tripId: tripId, busId: busId, action: action,
                                );
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: _buildUpcomingStop(name, badgeColor, action, waiting, isCurrent: isCurrent),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // CURRENT DECISION Banner — now uses live occupancy
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('stops').doc(currentStopId).get(),
              builder: (context, stopSnap) {
                int maxT = 25;
                if (stopSnap.hasData && stopSnap.data!.exists) {
                  final d = stopSnap.data!.data() as Map<String, dynamic>;
                  maxT = (d['maxThreshold'] ?? 25).toInt();
                }
                final int waiting = waitingPerStop[currentStopId] ?? 0;
                // Pass busCapacity so full-bus SKIP logic is applied
                final result = _decide(waiting, liveOccupancy, maxT, busCapacity);
                // NOTE: busCapacity is not in scope here, default 50 is safe since
                // the detailed next-stop card already handles the primary decision.
                final Color bgColor = result.action == DecisionService.actionStop
                    ? greenColor
                    : result.action == DecisionService.actionSkip
                        ? redColor
                        : yellowColor;
                final String action = result.action;
                final IconData decIcon = action == DecisionService.actionStop ? Icons.check_circle :
                                         action == DecisionService.actionSkip ? Icons.skip_next :
                                         Icons.warning_amber_rounded;

                return Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      const Text("CURRENT DECISION", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(decIcon, color: Colors.white, size: 36),
                          const SizedBox(width: 10),
                          Text(action, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildUpcomingStop(String name, Color badgeColor, String status, int waiting, {bool isCurrent = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                isCurrent ? Icons.navigation : Icons.circle,
                color: badgeColor,
                size: isCurrent ? 18 : 12,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isCurrent ? FontWeight.w900 : FontWeight.bold,
                        color: isCurrent ? Colors.black : Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isCurrent ? "$waiting waiting • Current" : "$waiting waiting",
                      style: TextStyle(fontSize: 12, color: isCurrent ? badgeColor : Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(20)),
          child: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(String busId, String routeId) {
    return AppBar(
      backgroundColor: AppTheme.maroon,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(busId.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(routeId, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
      actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Container(width: 12, height: 12, decoration: BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, border: Border.all(color: Colors.black, width: 1))),
                const SizedBox(width: 6),
                const Text("Online", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: Colors.white),
          onPressed: () => _showDriverSettings(busId, routeId),
        ),
        IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: _logout),
      ],
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  void _showDriverSettings(String busId, String routeId) {
    final user = FirebaseAuth.instance.currentUser;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text("Driver Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _driverInfoRow(Icons.email_outlined, "Email", user?.email ?? 'N/A'),
                      const Divider(height: 20),
                      _driverInfoRow(Icons.directions_bus, "Bus", busId.toUpperCase()),
                      const Divider(height: 20),
                      _driverInfoRow(Icons.route, "Route", routeId),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("Sign Out", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _driverInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.maroon, size: 20),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }

  Future<void> _logout() async {
    await Provider.of<AuthService>(context, listen: false).signOut();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }
}

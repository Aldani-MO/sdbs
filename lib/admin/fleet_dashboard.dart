import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FleetDashboardPage extends StatelessWidget {
  const FleetDashboardPage({super.key});

  static const Color greenColor = Color(0xFF4CAF50);
  static const Color redColor = Color(0xFFE91E63);
  static const Color amberColor = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Fleet Dashboard", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trips')
            .where('status', isEqualTo: 'Active')
            .snapshots(),
        builder: (context, tripSnap) {
          if (tripSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!tripSnap.hasData || tripSnap.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text("No active trips right now", style: TextStyle(color: Colors.grey, fontSize: 18)),
                  const SizedBox(height: 8),
                  Text("Trips will appear here when a driver is assigned", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                ],
              ),
            );
          }

          final trips = tripSnap.data!.docs;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary strip
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryItem("Active Buses", trips.length.toString(), Icons.directions_bus),
                      _buildSummaryItem("Online", trips.length.toString(), Icons.wifi, Colors.greenAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Active Buses", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...trips.map((tripDoc) {
                  final trip = tripDoc.data() as Map<String, dynamic>;
                  return _BusCard(
                    tripId: tripDoc.id,
                    busId: trip['busId'] ?? '',
                    routeId: trip['routeId'] ?? '',
                    driverId: trip['driverId'] ?? '',
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, [Color? iconColor]) {
    return Column(
      children: [
        Icon(icon, color: iconColor ?? Colors.white, size: 28),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ],
    );
  }
}

class _BusCard extends StatelessWidget {
  final String tripId;
  final String busId;
  final String routeId;
  final String driverId;

  const _BusCard({
    required this.tripId,
    required this.busId,
    required this.routeId,
    required this.driverId,
  });

  static const Color greenColor = Color(0xFF4CAF50);
  static const Color redColor = Color(0xFFE91E63);
  static const Color amberColor = Color(0xFFFFC107);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_bus, color: AppTheme.maroon, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(busId.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance.collection('routes').doc(routeId).get(),
                        builder: (context, snap) {
                          final name = (snap.hasData && snap.data!.exists)
                              ? (snap.data!.data() as Map<String, dynamic>)['name'] ?? routeId
                              : routeId;
                          return Text(name.toString(), style: TextStyle(color: Colors.grey[600], fontSize: 13));
                        },
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      const Text("Online", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Driver info
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(driverId).get(),
              builder: (context, snap) {
                String driverName = 'Unknown';
                if (snap.hasData && snap.data!.exists) {
                  final data = snap.data!.data() as Map<String, dynamic>;
                  driverName = "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}".trim();
                  if (driverName.isEmpty) driverName = data['email'] ?? 'Unknown';
                }
                return Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 6),
                    Text("Driver: $driverName", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Occupancy bar
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('buses').doc(busId).snapshots(),
              builder: (context, busSnap) {
                int occupancy = 0;
                int capacity = 50;
                if (busSnap.hasData && busSnap.data!.exists) {
                  final data = busSnap.data!.data() as Map<String, dynamic>;
                  occupancy = (data['currentOccupancy'] ?? 0) as int;
                  capacity = (data['capacity'] ?? 50) as int;
                }
                final pct = capacity > 0 ? (occupancy / capacity).clamp(0.0, 1.0) : 0.0;
                final fillColor = pct < 0.5 ? greenColor : pct < 0.8 ? amberColor : redColor;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Occupancy", style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
                        Text("$occupancy / $capacity", style: TextStyle(color: fillColor, fontWeight: FontWeight.bold, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),

            // Stop decisions — latest for this trip
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('checkIns')
                  .where('tripID', isEqualTo: tripId)
                  .snapshots(),
              builder: (context, checkSnap) {
                final total = checkSnap.hasData ? checkSnap.data!.docs.length : 0;
                return Row(
                  children: [
                    Icon(Icons.people_outline, color: Colors.grey[600], size: 18),
                    const SizedBox(width: 6),
                    Text("$total total check-ins", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

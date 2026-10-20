import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/transit_service.dart';
import '../utils/error_handler.dart';

class ManageTripsPage extends StatefulWidget {
  const ManageTripsPage({super.key});

  @override
  State<ManageTripsPage> createState() => _ManageTripsPageState();
}

class _ManageTripsPageState extends State<ManageTripsPage> {
  final _busIdController = TextEditingController();
  String? _selectedRouteId;
  String? _selectedDriverId;
  bool _isLoading = false;

  Future<void> _createTrip() async {
    if (_busIdController.text.isEmpty ||
        _selectedRouteId == null ||
        _selectedDriverId == null) {
      ErrorHandler.showError(context, 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final svc = Provider.of<TransitService>(context, listen: false);
      final busId = _busIdController.text.trim();

      // Validation: driver already on a trip?
      if (await svc.driverHasActiveTrip(_selectedDriverId!)) {
        if (mounted) ErrorHandler.showError(context, '⚠️ This driver already has an active trip!');
        setState(() => _isLoading = false);
        return;
      }

      // Validation: bus already on a trip?
      if (await svc.busHasActiveTrip(busId)) {
        if (mounted) ErrorHandler.showError(context, '⚠️ This bus is already on an active trip!');
        setState(() => _isLoading = false);
        return;
      }

      // Validation: route must be active
      if (!await svc.routeIsActive(_selectedRouteId!)) {
        if (mounted) ErrorHandler.showError(context, '⚠️ This route is inactive! Activate it first.');
        setState(() => _isLoading = false);
        return;
      }

      await svc.createTrip(
        busId: busId,
        routeId: _selectedRouteId!,
        driverId: _selectedDriverId!,
      );

      if (mounted) {
        ErrorHandler.showSuccess(context, 'Trip Created Successfully!');
        _busIdController.clear();
        setState(() {
          _selectedRouteId = null;
          _selectedDriverId = null;
        });
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _busIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transitService = Provider.of<TransitService>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text("Manage Trips",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── CREATE TRIP SECTION ──────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Create New Trip",
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),

                  // Bus ID
                  TextField(
                    controller: _busIdController,
                    decoration: InputDecoration(
                      labelText: "Bus ID (e.g. BUS-01)",
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.directions_bus),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Route dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: transitService.allRoutesStream(),
                    builder: (context, snapshot) {
                      final routes = snapshot.data?.docs ?? [];
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Select Route",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.route),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            hint: const Text("Choose a route..."),
                            value: _selectedRouteId,
                            items: routes.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  data['name'] ?? doc.id,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedRouteId = val),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Driver dropdown
                  StreamBuilder<QuerySnapshot>(
                    stream: transitService.driversStream(),
                    builder: (context, snapshot) {
                      final drivers = snapshot.data?.docs ?? [];
                      return InputDecorator(
                        decoration: InputDecoration(
                          labelText: "Select Driver",
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.person),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            hint: const Text("Choose a driver..."),
                            value: _selectedDriverId,
                            items: drivers.map((doc) {
                              final data =
                                  doc.data() as Map<String, dynamic>;
                              final driverName =
                                  "${data['firstName'] ?? ''} ${data['lastName'] ?? ''}"
                                      .trim();
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(
                                  driverName.isNotEmpty
                                      ? driverName
                                      : (data['email'] ?? doc.id),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _selectedDriverId = val),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.maroon,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text("Create Trip",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // ── ACTIVE TRIPS SECTION ────────────────────────────────
            const Text("Active Trips",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: transitService.activeTripsStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Text("No active trips.",
                      style: TextStyle(color: Colors.grey));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.1),
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.directions_bus,
                                  color: Colors.teal),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bus: ${data['busId'] ?? ''}",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  // Route name lookup
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('routes')
                                        .doc(data['routeId'] ?? '')
                                        .get(),
                                    builder: (context, routeSnap) {
                                      String routeName =
                                          data['routeId'] ?? '';
                                      if (routeSnap.hasData &&
                                          routeSnap.data!.exists) {
                                        final rData = routeSnap.data!.data()
                                            as Map<String, dynamic>;
                                        routeName =
                                            rData['name'] ?? routeName;
                                      }
                                      return Text(
                                        "Route: $routeName",
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 2),
                                  // Driver name lookup
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(data['driverId'] ?? '')
                                        .get(),
                                    builder: (context, driverSnap) {
                                      String driverName = 'Unknown';
                                      if (driverSnap.hasData &&
                                          driverSnap.data!.exists) {
                                        final dData = driverSnap.data!
                                            .data() as Map<String, dynamic>;
                                        driverName =
                                            "${dData['firstName'] ?? ''} ${dData['lastName'] ?? ''}"
                                                .trim();
                                        if (driverName.isEmpty) {
                                          driverName =
                                              dData['email'] ?? 'Unknown';
                                        }
                                      }
                                      return Text(
                                        "Driver: $driverName",
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.stop_circle,
                                  color: Colors.red, size: 30),
                              tooltip: "End Trip",
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("End Trip?"),
                                    content: const Text(
                                        "Are you sure you want to end this trip?"),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text("Cancel")),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text("End Trip",
                                              style: TextStyle(
                                                  color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await transitService.endTrip(doc.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 40),

            // ── ALL TRIPS SECTION ───────────────────────────────────
            const Text("All Trips",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('trips')
                  .orderBy('startTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Text("No trips found.",
                      style: TextStyle(color: Colors.grey));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'Unknown';
                    final isActive = status == 'Active';

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        child: Row(
                          children: [
                            Icon(
                              isActive
                                  ? Icons.play_circle_filled
                                  : Icons.check_circle,
                              color: isActive ? Colors.green : Colors.grey,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Bus: ${data['busId'] ?? ''}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('routes')
                                        .doc(data['routeId'] ?? '')
                                        .get(),
                                    builder: (context, routeSnap) {
                                      String routeName =
                                          data['routeId'] ?? '';
                                      if (routeSnap.hasData &&
                                          routeSnap.data!.exists) {
                                        final rData = routeSnap.data!.data()
                                            as Map<String, dynamic>;
                                        routeName =
                                            rData['name'] ?? routeName;
                                      }
                                      return Text(
                                        "Route: $routeName | Status: $status",
                                        style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 13),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Chip(
                              label: Text(status,
                                  style: TextStyle(
                                      color: isActive
                                          ? Colors.white
                                          : Colors.black54,
                                      fontSize: 12)),
                              backgroundColor: isActive
                                  ? Colors.green
                                  : Colors.grey.shade200,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
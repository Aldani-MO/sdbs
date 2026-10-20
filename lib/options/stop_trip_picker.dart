import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/transit_service.dart';
import '../utils/error_handler.dart';
import '../home/home.dart';

class StopTripPickerPage extends StatefulWidget {
  final String stopId;

  const StopTripPickerPage({super.key, required this.stopId});

  @override
  State<StopTripPickerPage> createState() => _StopTripPickerPageState();
}

class _StopTripPickerPageState extends State<StopTripPickerPage> {

  bool _isLoading = true;
  bool _checkedIn = false;
  bool _stopNotFound = false;
  String? _checkedInBus;
  String? _stopName;
  List<Map<String, dynamic>> _activeTrips = [];

  @override
  void initState() {
    super.initState();
    _loadTripsAtStop();
  }

  Future<void> _loadTripsAtStop() async {
    setState(() => _isLoading = true);
    try {
      final svc = Provider.of<TransitService>(context, listen: false);
      // Check if stop exists first
      final stopDoc = await FirebaseFirestore.instance.collection('stops').doc(widget.stopId).get();
      if (!stopDoc.exists) {
        if (mounted) setState(() => _stopNotFound = true);
        return;
      }
      final result = await svc.loadTripsAtStop(widget.stopId);
      if (mounted) {
        setState(() {
          _stopName = result.stopName;
          _activeTrips = result.trips;
        });
      }
    } catch (e) {
      debugPrint('Error loading trips at stop: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkIn(String tripId, String busId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not logged in');
      final svc = Provider.of<TransitService>(context, listen: false);
      await svc.processCheckIn(
        passengerId: user.uid,
        stopId: widget.stopId,
        tripId: tripId,
      );
      if (mounted) {
        setState(() { _checkedIn = true; _checkedInBus = busId; });
      }
    } catch (e) {
      if (mounted) ErrorHandler.showError(context, 'Check-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Select Your Bus', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _stopNotFound
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
                      child: const Icon(Icons.location_off, color: Colors.red, size: 60),
                    ),
                    const SizedBox(height: 28),
                    const Text('Stop Not Found', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Text(
                      'The stop code "${widget.stopId}" does not exist in the system.\nPlease check the code and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey[600], height: 1.5),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.maroon,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Go Back', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Finding buses at this stop…', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _checkedIn
              ? _buildSuccess()
              : _buildPicker(),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110, height: 110,
              decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 70),
            ),
            const SizedBox(height: 28),
            const Text('Checked In!', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              'You\'re waiting at\n${_stopName ?? 'your stop'}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, color: Colors.grey[600]),
            ),
            const SizedBox(height: 6),
            Text(
              'for $_checkedInBus',
              style: TextStyle(fontSize: 18, color: AppTheme.maroon, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('The driver will see you\'re waiting.', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
            const SizedBox(height: 44),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.maroon,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (_) => false,
                ),
                child: const Text('Back to Home', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppTheme.maroon.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.location_on, color: AppTheme.maroon, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stopName ?? 'Stop ${widget.stopId}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Stop ID: ${widget.stopId}', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Active trips at this stop
          Text(
            _activeTrips.isEmpty ? 'No active buses' : 'Active Buses at This Stop',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _activeTrips.isEmpty
                ? 'There are no buses currently running on routes that pass through this stop.'
                : 'Tap the bus you want to board.',
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (_activeTrips.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(
                  children: [
                    Icon(Icons.directions_bus_outlined, size: 80, color: Colors.grey[200]),
                    const SizedBox(height: 16),
                    Text('No buses right now', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _activeTrips.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final trip = _activeTrips[i];
                return _buildTripCard(trip);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _checkIn(trip['tripId'], trip['busId']),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                  child: Icon(Icons.directions_bus, color: Colors.green.shade600, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip['busId'],
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.maroon),
                      ),
                      const SizedBox(height: 4),
                      Text(trip['routeName'], style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.maroon,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Board', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

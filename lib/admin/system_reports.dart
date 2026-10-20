import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SystemReportsPage extends StatefulWidget {
  const SystemReportsPage({super.key});

  @override
  State<SystemReportsPage> createState() => _SystemReportsPageState();
}

class _SystemReportsPageState extends State<SystemReportsPage> {
  final Color greenColor = const Color(0xFF4CAF50);
  final Color redColor = const Color(0xFFE91E63);
  final Color amberColor = const Color(0xFFFFC107);

  int _totalUsers = 0;
  int _totalStops = 0;
  int _totalCheckIns = 0;
  int _totalRoutes = 0;
  int _activeTrips = 0;
  int _stopCount = 0;
  int _skipCount = 0;
  int _earlyCount = 0;
  double _avgOccupancy = 0.0;
  int _peakOccupancy = 0;
  List<_StopCheckInData> _stopCheckIns = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllAnalytics();
  }

  Future<void> _loadAllAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').count().get(),
        FirebaseFirestore.instance.collection('stops').count().get(),
        FirebaseFirestore.instance.collection('checkIns').count().get(),
        FirebaseFirestore.instance.collection('routes').count().get(),
        FirebaseFirestore.instance.collection('trips').where('status', isEqualTo: 'Active').count().get(),
      ]);
      _totalUsers = results[0].count ?? 0;
      _totalStops = results[1].count ?? 0;
      _totalCheckIns = results[2].count ?? 0;
      _totalRoutes = results[3].count ?? 0;
      _activeTrips = results[4].count ?? 0;

      final decisions = await FirebaseFirestore.instance.collection('stopDecisions').get();
      _stopCount = 0; _skipCount = 0; _earlyCount = 0;
      for (var doc in decisions.docs) {
        final action = (doc.data()['action'] ?? '').toString();
        if (action == 'STOP') {
          _stopCount++;
        } else if (action == 'SKIP') {
          _skipCount++;
        } else if (action == 'EARLY DEPART') {
          _earlyCount++;
        }
      }

      final occRecords = await FirebaseFirestore.instance.collection('occupancyRecords').limit(100).get();
      if (occRecords.docs.isNotEmpty) {
        int totalOcc = 0; int peak = 0;
        for (var doc in occRecords.docs) {
          final count = (doc.data()['count'] ?? 0) as int;
          totalOcc += count;
          if (count > peak) peak = count;
        }
        _avgOccupancy = totalOcc / occRecords.docs.length;
        _peakOccupancy = peak;
      }

      final checkIns = await FirebaseFirestore.instance.collection('checkIns').get();
      Map<String, int> stopCounts = {};
      for (var doc in checkIns.docs) {
        final stopId = doc.data()['stopID']?.toString() ?? '';
        if (stopId.isNotEmpty) stopCounts[stopId] = (stopCounts[stopId] ?? 0) + 1;
      }
      List<_StopCheckInData> stopData = [];
      for (var entry in stopCounts.entries) {
        final stopDoc = await FirebaseFirestore.instance.collection('stops').doc(entry.key).get();
        final name = stopDoc.exists ? (stopDoc.data()?['name'] ?? entry.key).toString() : entry.key;
        stopData.add(_StopCheckInData(name: name, count: entry.value));
      }
      stopData.sort((a, b) => b.count.compareTo(a.count));
      _stopCheckIns = stopData.take(10).toList();
    } catch (e) {
      debugPrint('[REPORTS ERROR] $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics & Reports", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.maroon,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadAllAnalytics, tooltip: 'Refresh'),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllAnalytics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("System Overview", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 360 ? 2 : 3;
                        return GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: crossAxisCount == 2 ? 1.3 : 1.0,
                          children: [
                            _buildKpiCard("Users", _totalUsers.toString(), Icons.people, Colors.blue),
                            _buildKpiCard("Stops", _totalStops.toString(), Icons.location_on, Colors.green),
                            _buildKpiCard("Check-Ins", _totalCheckIns.toString(), Icons.check_circle, Colors.orange),
                            _buildKpiCard("Routes", _totalRoutes.toString(), Icons.route, Colors.purple),
                            _buildKpiCard("Active Trips", _activeTrips.toString(), Icons.trip_origin, Colors.teal),
                            _buildKpiCard("Avg Occupancy", _avgOccupancy.toStringAsFixed(1), Icons.people_outline, Colors.indigo),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 28),
                    const Text("Decision Engine Analytics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Based on ${_stopCount + _skipCount + _earlyCount} total decisions", style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    _buildDecisionChart(),
                    const SizedBox(height: 28),
                    const Text("Occupancy Statistics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildStatCard("Average", _avgOccupancy.toStringAsFixed(1), "passengers/bus", Colors.blue)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildStatCard("Peak", _peakOccupancy.toString(), "highest count", Colors.red)),
                      ],
                    ),
                    const SizedBox(height: 28),
                    const Text("Check-Ins by Stop", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Most popular stops", style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(height: 16),
                    _buildBarChart(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionChart() {
    final total = _stopCount + _skipCount + _earlyCount;
    if (total == 0) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No decisions recorded yet.\nDecisions appear when the Driver Dashboard runs.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))),
      );
    }
    final stopPct = (_stopCount / total * 100).round();
    final skipPct = (_skipCount / total * 100).round();
    final earlyPct = (_earlyCount / total * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Center(
            child: SizedBox(
              height: 180,
              width: 180,
              child: CustomPaint(
                size: const Size(180, 180),
                painter: _PieChartPainter(
                  stopPct: _stopCount / total,
                  skipPct: _skipCount / total,
                  earlyPct: _earlyCount / total,
                  greenColor: greenColor,
                  redColor: redColor,
                  amberColor: amberColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceEvenly,
            spacing: 16,
            runSpacing: 12,
            children: [
              _buildLegendItem("STOP", _stopCount, "$stopPct%", greenColor),
              _buildLegendItem("SKIP", _skipCount, "$skipPct%", redColor),
              _buildLegendItem("EARLY DEPART", _earlyCount, "$earlyPct%", amberColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, int count, String pct, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text("$count ($pct)", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBarChart() {
    if (_stopCheckIns.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: const Center(child: Text("No check-in data yet.", style: TextStyle(color: Colors.grey))),
      );
    }
    final maxCount = _stopCheckIns.first.count;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: _stopCheckIns.map((stop) {
          final pct = maxCount > 0 ? stop.count / maxCount : 0.0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(stop.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    Text("${stop.count}", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.maroon)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.maroon),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

}

class _StopCheckInData {
  final String name;
  final int count;
  _StopCheckInData({required this.name, required this.count});
}

class _PieChartPainter extends CustomPainter {
  final double stopPct, skipPct, earlyPct;
  final Color greenColor, redColor, amberColor;

  _PieChartPainter({
    required this.stopPct, required this.skipPct, required this.earlyPct,
    required this.greenColor, required this.redColor, required this.amberColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const startAngle = -1.5708;
    const total = 6.2832;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 30
      ..strokeCap = StrokeCap.butt;

    double current = startAngle;

    paint.color = greenColor;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), current, total * stopPct, false, paint);
    current += total * stopPct;

    paint.color = redColor;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), current, total * skipPct, false, paint);
    current += total * skipPct;

    paint.color = amberColor;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), current, total * earlyPct, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

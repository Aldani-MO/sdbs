import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../home/home.dart';
import '../home/profile.dart';
import '../home/cards.dart';

class RoutesPage extends StatefulWidget {
  const RoutesPage({super.key});

  @override
  State<RoutesPage> createState() => _RoutesPageState();
}

class _RoutesPageState extends State<RoutesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Cache all stops so we can search by name/ID instantly
  Map<String, Map<String, dynamic>> _stopsCache = {};

  @override
  void initState() {
    super.initState();
    _loadStops();
  }

  Future<void> _loadStops() async {
    final snap = await FirebaseFirestore.instance.collection('stops').get();
    final map = <String, Map<String, dynamic>>{};
    for (var doc in snap.docs) {
      map[doc.id] = {...doc.data(), 'id': doc.id};
    }
    if (mounted) setState(() => _stopsCache = map);
  }

  /// Check if a route matches the search query (by route name, stop name, or stop ID)
  bool _routeMatchesSearch(Map<String, dynamic> routeData, List<dynamic> stopIds) {
    if (_searchQuery.isEmpty) return true;
    final q = _searchQuery.toLowerCase();

    // Match route name
    final routeName = (routeData['name'] ?? '').toString().toLowerCase();
    if (routeName.contains(q)) return true;

    // Match any stop name or stop ID
    for (var stopId in stopIds) {
      final sid = stopId.toString().toLowerCase();
      if (sid.contains(q)) return true;
      final stopData = _stopsCache[stopId.toString()];
      if (stopData != null) {
        final stopName = (stopData['name'] ?? '').toString().toLowerCase();
        if (stopName.contains(q)) return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        elevation: 0,
        title: const Text('Routes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HomePage()));
            }
          },
        ),
      ),
      body: Column(
        children: [
          // ── Info banner + Search ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
            decoration: const BoxDecoration(
              color: AppTheme.maroon,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Browse all available bus routes and their stops.',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'To board a bus, scan the QR code at the physical stop.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Search bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by route, stop name, or stop ID…',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                      prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.8)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.8), size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Routes list ─────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('routes')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No active routes available',
                        style: TextStyle(fontSize: 16, color: Colors.grey)),
                  );
                }

                final allRoutes = snapshot.data!.docs;

                // Filter by search
                final routes = allRoutes.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final stopIds = data['stopIds'] ?? [];
                  return _routeMatchesSearch(data, stopIds);
                }).toList();

                if (routes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No routes match "$_searchQuery"',
                            style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    final routeData = route.data() as Map<String, dynamic>;
                    final String routeName = routeData['name'] ?? 'Unnamed Route';
                    final List<dynamic> stopIds = routeData['stopIds'] ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          leading: Hero(
                            tag: 'route_icon_${route.id}',
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.maroon.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.route, color: AppTheme.maroon, size: 22),
                            ),
                          ),
                          title: Text(routeName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Text('${stopIds.length} stops · ID: ${route.id}',
                              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                          children: [
                            if (stopIds.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                                child: Text('No stops assigned to this route yet.',
                                    style: TextStyle(color: Colors.grey)),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  children: [
                                    // Route line visual
                                    ...stopIds.asMap().entries.map((entry) {
                                      final int i = entry.key;
                                      final String stopId = entry.value.toString();
                                      final bool isLast = i == stopIds.length - 1;

                                      // Use cache if available, else FutureBuilder
                                      final cachedStop = _stopsCache[stopId];
                                      final String stopName = cachedStop != null
                                          ? (cachedStop['name'] ?? 'Stop $stopId')
                                          : 'Loading…';

                                      return _buildStopRow(i, isLast, stopId, stopName, stopIds.length);
                                    }),
                                  ],
                                ),
                              ),
                          ],
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const CardsPage()));
          } else if (index == 1) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const HomePage()));
          } else if (index == 2) {
            Navigator.pushReplacement(
                context, MaterialPageRoute(builder: (_) => const ProfilePage()));
          }
        },
        selectedItemColor: AppTheme.maroon,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Cards'),
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildStopRow(int i, bool isLast, String stopId, String stopName, int totalStops) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: i == 0
                        ? AppTheme.maroon
                        : isLast
                            ? Colors.green
                            : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == 0
                          ? AppTheme.maroon
                          : isLast
                              ? Colors.green
                              : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: (i == 0 || isLast)
                            ? Colors.white
                            : Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Stop info — show name AND Stop ID
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stopName,
                    style: TextStyle(
                      fontWeight: i == 0 || isLast
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    i == 0
                        ? 'First stop · ID: $stopId'
                        : isLast
                            ? 'Last stop · ID: $stopId'
                            : 'Stop ${i + 1} · ID: $stopId',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

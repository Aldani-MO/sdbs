import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../auth/login.dart';
import '../services/auth_service.dart';
import 'manage_users.dart';
import 'manage_stops.dart';
import 'manage_routes.dart';
import 'system_reports.dart';
import 'manage_trips.dart';
import 'fleet_dashboard.dart';

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        title: const Text("Admin Control Center",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await Provider.of<AuthService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Operations",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildAdminCard(
                    context,
                    title: "Manage Users",
                    icon: Icons.people_alt_outlined,
                    color: Colors.blueAccent,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageUsersPage()));
                    },
                  ),
                  _buildAdminCard(
                    context,
                    title: "Manage Stops",
                    icon: Icons.add_location_alt_outlined,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageStopsPage()));
                    },
                  ),
                  _buildAdminCard(
                    context,
                    title: "Manage Routes",
                    icon: Icons.route_outlined,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageRoutesPage()));
                    },
                  ),
                  _buildAdminCard(
                    context,
                    title: "Manage Trips",
                    icon: Icons.trip_origin_outlined,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageTripsPage()));
                    },
                  ),
                  _buildAdminCard(
                    context,
                    title: "System Reports",
                    icon: Icons.bar_chart_outlined,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemReportsPage()));
                    },
                  ),
                  _buildAdminCard(
                    context,
                    title: "Live Fleet",
                    icon: Icons.gps_fixed_outlined,
                    color: Colors.red,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const FleetDashboardPage()));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

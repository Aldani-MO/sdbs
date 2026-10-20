import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/transit_service.dart';
import '../services/wallet_service.dart';
import '../utils/error_handler.dart';
import '../options/notifications.dart';
import '../auth/login.dart';

import '../options/check_in.dart';
import '../options/routes_page.dart';
import 'profile.dart';
import 'cards.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final int _selectedIndex = 1;

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CardsPage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
    }
  }

  void _showSettingsSheet() {
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
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                const Text("Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _settingsTile(Icons.lock_outline, "Change Password", () {
                  Navigator.pop(context);
                  _showChangePasswordDialog();
                }),
                const Divider(),
                _settingsTile(Icons.logout, "Sign Out", () async {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  await Provider.of<AuthService>(context, listen: false).signOut();
                  if (mounted) {
                    navigator.pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
                  }
                }, isDestructive: true),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : AppTheme.maroon),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: isDestructive ? Colors.red : Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Change Password"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              )
            else ...[
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancel")),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.maroon),
                onPressed: () async {
                  if (currentPassCtrl.text.isEmpty) {
                    ErrorHandler.showError(context, 'Please enter your current password');
                    return;
                  }
                  if (newPassCtrl.text != confirmPassCtrl.text) {
                    ErrorHandler.showError(context, "Passwords don't match");
                    return;
                  }
                  if (newPassCtrl.text.length < 8) {
                    ErrorHandler.showError(context, 'Password must be at least 8 characters');
                    return;
                  }

                  // Capture messenger before async gap
                  final messenger = ScaffoldMessenger.of(context);
                  setStateDialog(() => isLoading = true);

                  try {
                    await Provider.of<AuthService>(context, listen: false)
                        .changePassword(currentPassCtrl.text, newPassCtrl.text);
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    ErrorHandler.showSuccessOnMessenger(messenger, 'Password changed successfully!');
                  } catch (e) {
                    setStateDialog(() => isLoading = false);
                    ErrorHandler.showErrorOnMessenger(messenger, _friendlyPasswordError(e));
                  }
                },
                child: const Text("Update", style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    ).then((_) {
      currentPassCtrl.dispose();
      newPassCtrl.dispose();
      confirmPassCtrl.dispose();
    });
  }

  String _friendlyPasswordError(Object error) {
    final msg = error.toString();
    if (msg.contains('wrong-password') || msg.contains('invalid-credential')) {
      return 'Current password is incorrect.';
    }
    if (msg.contains('requires-recent-login')) {
      return 'Please log out and log back in, then try again.';
    }
    if (msg.contains('weak-password')) {
      return 'New password is too weak.';
    }
    if (msg.contains('network-request-failed')) {
      return 'No internet connection.';
    }
    return 'Failed to change password. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Card ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                decoration: BoxDecoration(
                  color: AppTheme.maroon,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: user != null
                      ? Provider.of<WalletService>(context, listen: false).userProfileStream(user.uid)
                      : const Stream.empty(),
                  builder: (context, snapshot) {
                    String name = "Welcome!";
                    double balance = 0.0;
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      name = data['firstName'] ?? 'User';
                      balance = (data['balance'] ?? 0.0).toDouble();
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Good day,", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14)),
                                const SizedBox(height: 4),
                                Text(
                                  name,
                                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text("Balance", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                                      Text(
                                        "${balance.toStringAsFixed(2)} JOD",
                                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _showSettingsSheet,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.settings, color: Colors.white, size: 22),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        // Search bar — tapping navigates to Routes page with search
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutesPage())),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 14),
                                Icon(Icons.search, color: Colors.white.withValues(alpha: 0.8)),
                                const SizedBox(width: 10),
                                Text('Search for routes…', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 28),

              // ── Live Trip Status Strip ────────────────────────────────────
              // Show the bus this passenger checked into, not a random active trip
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: StreamBuilder<QuerySnapshot>(
                  stream: user != null
                      ? Provider.of<TransitService>(context, listen: false).checkInsForPassenger(user.uid)
                      : const Stream.empty(),
                  builder: (context, checkInSnap) {
                    if (!checkInSnap.hasData || checkInSnap.data!.docs.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[400]),
                            const SizedBox(width: 12),
                            const Text("No active trips — check in first", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    // Find the most recent check-in by sorting locally
                    final checkInDocs = checkInSnap.data!.docs;
                    checkInDocs.sort((a, b) {
                      final aData = a.data() as Map<String, dynamic>;
                      final bData = b.data() as Map<String, dynamic>;
                      final aTime = aData['timeStamp'] as Timestamp?;
                      final bTime = bData['timeStamp'] as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime);
                    });

                    final latestCheckIn = checkInDocs.first.data() as Map<String, dynamic>;
                    final tripId = latestCheckIn['tripID'] ?? '';

                    if (tripId.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[400]),
                            const SizedBox(width: 12),
                            const Text("No active trips — check in first", style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    // Now load the trip the passenger checked into
                    return StreamBuilder<DocumentSnapshot>(
                      stream: Provider.of<TransitService>(context, listen: false).tripStream(tripId),
                      builder: (context, snap) {
                        if (!snap.hasData || !snap.data!.exists) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.grey[400]),
                                const SizedBox(width: 12),
                                const Text("No active trips — check in first", style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          );
                        }

                    final trip = snap.data!.data() as Map<String, dynamic>;
                    final busId = (trip['busId'] ?? '').toString();
                    final busIdUpper = busId.toUpperCase();
                    final routeId = trip['routeId'] ?? '';

                    return FutureBuilder<DocumentSnapshot>(
                      future: Provider.of<TransitService>(context, listen: false).getRoute(routeId),
                      builder: (context, routeSnap) {
                        String routeName = routeId;
                        if (routeSnap.hasData && routeSnap.data!.exists) {
                          routeName = (routeSnap.data!.data() as Map<String, dynamic>)['name'] ?? routeId;
                        }

                        return Column(
                          children: [
                            // Trip info row
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: Row(
                                children: [
                                  Hero(
                                    tag: 'bus_icon_$busId',
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                                      child: Icon(Icons.directions_bus, color: Colors.green.shade600, size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(busIdUpper, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(routeName, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                                    child: Row(
                                      children: [
                                        Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                                        const SizedBox(width: 6),
                                        const Text("Live", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            // FR-04: Live Bus Occupancy Viewer
                            StreamBuilder<DocumentSnapshot>(
                              stream: Provider.of<TransitService>(context, listen: false).busStream(busId),
                              builder: (context, busSnap) {
                                int occupancy = 0;
                                int capacity = 50;
                                if (busSnap.hasData && busSnap.data!.exists) {
                                  final busData = busSnap.data!.data() as Map<String, dynamic>;
                                  occupancy = (busData['currentOccupancy'] ?? 0) as int;
                                  capacity = (busData['capacity'] ?? 50) as int;
                                }
                                final double fillPercent = capacity > 0 ? (occupancy / capacity).clamp(0.0, 1.0) : 0.0;
                                final Color fillColor = fillPercent < 0.5
                                    ? Colors.green
                                    : fillPercent < 0.8
                                        ? Colors.orange
                                        : Colors.red;
                                final String fillLabel = fillPercent < 0.5
                                    ? 'Seats Available'
                                    : fillPercent < 0.8
                                        ? 'Filling Up'
                                        : 'Almost Full';

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.people, color: fillColor, size: 22),
                                          const SizedBox(width: 8),
                                          const Text("Bus Occupancy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: fillColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                            child: Text(fillLabel, style: TextStyle(color: fillColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      // Progress bar
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: LinearProgressIndicator(
                                          value: fillPercent,
                                          minHeight: 12,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "$occupancy / $capacity passengers",
                                        style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600),
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
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // ── Quick Actions Grid ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildMenuItem(
                          icon: Icons.directions_bus_outlined,
                          label: 'Routes',
                          subtitle: 'View all routes',
                          color: const Color(0xFF6B4EFF),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutesPage())),
                        ),
                        _buildMenuItem(
                          icon: Icons.qr_code_scanner,
                          label: 'Check In',
                          subtitle: 'Board your bus',
                          color: AppTheme.maroon,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInPage())),
                        ),
                        // Notifications with unread badge
                        StreamBuilder<QuerySnapshot>(
                          stream: user != null
                              ? Provider.of<TransitService>(context, listen: false).unreadNotificationsStream(user.uid)
                              : const Stream.empty(),
                          builder: (context, notifSnap) {
                            final unreadCount = notifSnap.hasData ? notifSnap.data!.docs.length : 0;
                            return SizedBox.expand(
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: _buildMenuItem(
                                      icon: Icons.notifications_outlined,
                                      label: 'Notifications',
                                      subtitle: 'Alerts & updates',
                                      color: const Color(0xFFFF6B35),
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage())),
                                    ),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      top: -4,
                                      right: -4,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                        child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Wallet',
                          subtitle: 'Top up & history',
                          color: const Color(0xFF10B981),
                          onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CardsPage())),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: AppTheme.maroon,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'Cards'),
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

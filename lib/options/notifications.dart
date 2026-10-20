import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/transit_service.dart';
import '../home/home.dart';
import '../home/profile.dart';
import '../home/cards.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final Color lightPinkColor = const Color(0xFFF8E7EB);

  void _onItemTapped(int index) {
    if (index == 0) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const CardsPage()));
    } else if (index == 1) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomePage()));
    } else if (index == 2) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppTheme.maroon,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Notifications',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: user == null
          ? const Center(child: Text('Please log in.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text("Error: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        const Text(
                          'No notifications yet.',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You will be notified when a bus skips\nyour stop or your trip is complete.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                final notifications = snapshot.data!.docs;

                // Sort locally by timestamp instead of using Firestore orderBy (avoids requiring index)
                notifications.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp?;
                  final bTime = bData['timestamp'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime); // descending
                });

                return Column(
                  children: [
                    // Mark all as read button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              Provider.of<TransitService>(context, listen: false)
                                  .markAllNotificationsRead(notifications);
                            },
                            icon: const Icon(Icons.done_all, size: 18),
                            label: const Text("Mark all read"),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.maroon),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final data = notifications[index].data() as Map<String, dynamic>;
                          final bool isRead = data['read'] == true;

                          IconData icon = Icons.notifications;
                          final type = data['type'] ?? '';
                          if (type == 'skip') icon = Icons.skip_next;
                          if (type == 'delay') icon = Icons.access_time;
                          if (type == 'trip_complete') icon = Icons.check_circle;
                          if (type == 'welcome') icon = Icons.celebration;

                          return GestureDetector(
                            onTap: () {
                            if (!isRead) {
                              Provider.of<TransitService>(context, listen: false)
                                  .markNotificationRead(notifications[index].reference);
                            }
                          },
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: _buildNotificationCard(
                                icon: icon,
                                title: data['title'] ?? 'Notification',
                                description: data['description'] ?? '',
                                time: _formatTimestamp(data['timestamp']),
                                isRead: isRead,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        onTap: _onItemTapped,
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

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String description,
    required String time,
    bool isRead = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey.shade100 : lightPinkColor,
        borderRadius: BorderRadius.circular(20),
        border: isRead ? null : Border.all(color: AppTheme.maroon.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.maroon, size: 50),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(height: 5),
                    Text(description, style: const TextStyle(fontSize: 14, color: Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(time, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    if (timestamp is Timestamp) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inMinutes < 1) return "Just now";
      if (diff.inHours < 1) return "${diff.inMinutes} min ago";
      if (diff.inDays < 1) return "${diff.inHours} hours ago";
      return "${diff.inDays} days ago";
    }
    return "";
  }
}

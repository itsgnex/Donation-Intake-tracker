import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'store_schedule_view.dart';
import 'confirm_readiness_page.dart';
import '../profile/store_profile_edit.dart';
import 'store_unavailable_days_page.dart';
import 'store_volunteer_details.dart';

/// Dashboard shown to store partners after they log in.
class StoreDashboard extends StatelessWidget {
  const StoreDashboard({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      'storeLogin',
          (route) => false,
    );
  }

  Stream<QuerySnapshot> _storeSchedulesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('schedules')
        .where('storeId', isEqualTo: uid)
        .snapshots();
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Store Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Log out',
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/store_bg.jpg',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Welcome, Store Partner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your donation pickups and store information.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                StreamBuilder<QuerySnapshot>(
                  stream: _storeSchedulesStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        height: 70,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return const _NextPickupCard(
                        title: 'Could not load schedule',
                        subtitle: 'Please try again later.',
                        icon: Icons.error_outline,
                      );
                    }

                    final rawDocs = snapshot.data?.docs ?? [];
                    if (rawDocs.isEmpty) {
                      return const _NextPickupCard(
                        title: 'No pickup scheduled',
                        subtitle:
                        'Staff have not assigned a pickup to this store yet.',
                        icon: Icons.event_busy,
                      );
                    }

                    final now = DateTime.now();
                    final todayOnly =
                    DateTime(now.year, now.month, now.day);

                    final docs = rawDocs.where((doc) {
                      final data =
                          doc.data() as Map<String, dynamic>? ?? {};
                      final ts = data['pickupDate'] as Timestamp?;
                      if (ts == null) return false;
                      final d = ts.toDate();
                      final dateOnly =
                      DateTime(d.year, d.month, d.day);
                      return dateOnly.isAtSameMomentAs(todayOnly) ||
                          dateOnly.isAfter(todayOnly);
                    }).toList();

                    final relevant = docs.isEmpty ? rawDocs : docs;

                    relevant.sort((a, b) {
                      final da = (a.data()
                      as Map<String, dynamic>? ??
                          {})['pickupDate'] as Timestamp?;
                      final db = (b.data()
                      as Map<String, dynamic>? ??
                          {})['pickupDate'] as Timestamp?;
                      final ta = da?.toDate() ?? DateTime.now();
                      final tb = db?.toDate() ?? DateTime.now();
                      return ta.compareTo(tb);
                    });

                    final data = relevant.first.data()
                    as Map<String, dynamic>? ??
                        {};
                    final ts = data['pickupDate'] as Timestamp?;
                    final startTime =
                    (data['startTime'] as String? ?? '').trim();
                    final endTime =
                    (data['endTime'] as String? ?? '').trim();
                    final timeWindow =
                    (data['timeWindow'] as String? ?? '').trim();
                    final volunteerName =
                    (data['volunteerName'] as String? ?? '').trim();
                    final status =
                    (data['status'] as String? ?? 'scheduled').trim();

                    String scheduleLine;
                    if (ts == null) {
                      scheduleLine = 'Pickup date not set';
                    } else {
                      final dateText = _formatDate(ts);
                      if (startTime.isNotEmpty && endTime.isNotEmpty) {
                        scheduleLine =
                        'Pickup on $dateText • $startTime - $endTime';
                      } else if (timeWindow.isNotEmpty) {
                        scheduleLine =
                        'Pickup on $dateText • $timeWindow';
                      } else {
                        scheduleLine = 'Pickup date: $dateText';
                      }
                    }

                    final volunteerLine = volunteerName.isEmpty
                        ? 'Volunteer not assigned yet'
                        : 'Volunteer: $volunteerName';

                    final statusLine = status == 'ready'
                        ? 'Status: Ready (confirmed by store)'
                        : 'Status: Scheduled';

                    final subtitle =
                        '$scheduleLine\n$volunteerLine\n$statusLine';

                    return _NextPickupCard(
                      title: 'Next pickup scheduled',
                      subtitle: subtitle,
                      icon: Icons.event_available,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      StoreDashboardCard(
                        title: 'Pickup Schedule',
                        subtitle: 'View all upcoming pickups',
                        icon: Icons.event,
                        color: Colors.lightBlueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StoreScheduleViewPage(),
                            ),
                          );
                        },
                      ),
                      StoreDashboardCard(
                        title: 'Confirm Readiness',
                        subtitle: 'Tell volunteers food is ready',
                        icon: Icons.check_circle_outline,
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const ConfirmReadinessPage(),
                            ),
                          );
                        },
                      ),
                      StoreDashboardCard(
                        title: 'Update Store Info',
                        subtitle: 'Contact and location',
                        icon: Icons.store_mall_directory,
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StoreProfileEditPage(),
                            ),
                          );
                        },
                      ),
                      StoreDashboardCard(
                        title: 'Volunteer Details',
                        subtitle: 'See who is coming',
                        icon: Icons.people_outline,
                        color: Colors.purpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StoreVolunteerDetailsPage(),
                            ),
                          );
                        },
                      ),
                      StoreDashboardCard(
                        title: 'Unavailable Days',
                        subtitle: 'Mark days off',
                        icon: Icons.calendar_today,
                        color: Colors.tealAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StoreUnavailableDaysPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NextPickupCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _NextPickupCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.lightBlueAccent.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 26,
              color: Colors.lightBlueAccent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$title\n$subtitle',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StoreDashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const StoreDashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.92),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: color.withOpacity(0.18),
              ),
              child: Icon(
                icon,
                size: 26,
                color: color.withOpacity(0.95),
              ),
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

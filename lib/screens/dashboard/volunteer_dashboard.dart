import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../donations/add_donation.dart';
import '../donations/volunteer_view_donation.dart';
import '../donations/volunteer_recent_donations.dart';
import '../profile/volunteer_profile.dart';
import 'volunteer_schedule_view.dart';
import 'volunteer_upcoming_assignments.dart'; // 👈 NEW: upcoming assignments screen

class VolunteerDashboard extends StatelessWidget {
  const VolunteerDashboard({super.key});

  /// Log the volunteer out and return to the volunteer login screen.
  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      'volunteerLogin', // use whatever route name you have
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: const Text(
          'Volunteer dashboard',
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
          // Background image (same as other dashboards)
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay so content is readable
          Container(color: Colors.black.withOpacity(0.55)),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Welcome, Volunteer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage your donations and schedule.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                // Dashboard tiles
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      // Add donation
                      DashboardCard(
                        title: 'Add donation',
                        subtitle: 'Log new donation boxes',
                        icon: Icons.add_box_outlined,
                        color: Colors.purpleAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddDonationPage(),
                            ),
                          );
                        },
                      ),

                      // My donations (full history)
                      DashboardCard(
                        title: 'My donations',
                        subtitle: 'View past entries',
                        icon: Icons.inventory_2_outlined,
                        color: Colors.tealAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerViewDonationPage(),
                            ),
                          );
                        },
                      ),

                      // Recent activity (last donations with status)
                      DashboardCard(
                        title: 'Recent activity',
                        subtitle: 'Last 5 donations',
                        icon: Icons.history,
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerRecentDonationsPage(),
                            ),
                          );
                        },
                      ),

                      // My schedule (existing schedule view)
                      DashboardCard(
                        title: 'My schedule',
                        subtitle: 'See upcoming pickups',
                        icon: Icons.event,
                        color: Colors.lightBlueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerScheduleViewPage(),
                            ),
                          );
                        },
                      ),

                      // NEW: My assignments (story #13)
                      // Uses VolunteerUpcomingAssignmentsPage which lists
                      // all upcoming assignments from the central schedule
                      // with store name, time and location.
                      DashboardCard(
                        title: 'My assignments',
                        subtitle: 'Plan my pickup routes',
                        icon: Icons.route,
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerUpcomingAssignmentsPage(),
                            ),
                          );
                        },
                      ),

                      // Profile
                      DashboardCard(
                        title: 'Profile',
                        subtitle: 'Check your details',
                        icon: Icons.person_outline,
                        color: Colors.pinkAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerProfilePage(),
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

/// Same style as the DashboardCard in StoreDashboard
class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
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
            // Icon pill
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
            // Card title
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Card subtitle
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

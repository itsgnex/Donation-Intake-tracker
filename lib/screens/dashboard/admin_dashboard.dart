import 'package:flutter/material.dart';

import 'staff_invites_page.dart';
import 'analytics_dashboard.dart';
import 'manage_schedules.dart';
import 'manage_stores.dart';
import 'manage_volunteers.dart';
import 'delivery_tracking_page.dart';
import '../../services/auth_service.dart';

// Donations-related screens (in ../donations)
import '../donations/donation_reports_dashboard.dart';
import '../donations/manual_donation_entry.dart';
import '../donations/edit_donation_admin.dart';
import 'view_donations_admin.dart';
import 'reports_dashboard.dart';

/// Main dashboard for staff/admin users.
///
/// From here staff can navigate to all management / analytics screens.
/// This widget is stateless: navigation + logout are delegated to callbacks.
class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  /// Sign out the currently logged-in admin/staff user and
  /// navigate back to the admin login route, clearing the stack.
  Future<void> _logout(BuildContext context) async {
    await AuthService.signOut();
    Navigator.pushNamedAndRemoveUntil(
      context,
      'adminLogin',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use black so the background image fade looks consistent.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Staff dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          Image.asset(
            'assets/staff_bg.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay on top of image
          Container(color: Colors.black.withOpacity(0.55)),
          // Foreground content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text(
                  'Welcome, staff member',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage schedules, stores, volunteers and donations.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                // Main grid of navigation tiles
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    children: [
                      // ───────────── Row 1 ─────────────
                      DashboardCard(
                        title: 'Manage schedules',
                        subtitle: 'Create and edit pickup times',
                        icon: Icons.schedule_outlined,
                        color: Colors.lightBlueAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageSchedulesPage(),
                            ),
                          );
                        },
                      ),
                      DashboardCard(
                        title: 'Manage stores',
                        subtitle: 'Add and edit store partners',
                        icon: Icons.storefront_outlined,
                        color: Colors.orangeAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageStoresPage(),
                            ),
                          );
                        },
                      ),

                      // ───────────── Row 2 ─────────────
                      DashboardCard(
                        title: 'Manage volunteers',
                        subtitle: 'Assign and update volunteers',
                        icon: Icons.group_outlined,
                        color: Colors.pinkAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ManageVolunteersPage(),
                            ),
                          );
                        },
                      ),
                      DashboardCard(
                        title: 'Coverage',
                        subtitle: 'Stores and assigned volunteers',
                        icon: Icons.map_outlined,
                        color: Colors.greenAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const AnalyticsDashboardPage(),
                            ),
                          );
                        },
                      ),

                      // ───────────── Row 3 ─────────────
                      DashboardCard(
                        title: 'Donation reports',
                        subtitle: 'Totals and filters for reports',
                        icon: Icons.bar_chart_outlined,
                        color: Colors.amberAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const ReportsDashboardPage(),
                            ),
                          );
                        },
                      ),
                      DashboardCard(
                        title: 'Manual donation entry',
                        subtitle: 'Add missing donation records',
                        icon: Icons.edit_note_outlined,
                        color: Colors.indigoAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const ManualDonationEntryPage(),
                            ),
                          );
                        },
                      ),

                      // ───────────── Row 4 ─────────────
                      DashboardCard(
                        title: 'Review donations',
                        subtitle: 'Edit or approve entries',
                        icon: Icons.checklist_outlined,
                        color: Colors.purpleAccent,
                        // Navigates to the admin donations list/review page
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                              const ViewDonationsAdminPage(),
                            ),
                          );
                        },
                      ),
                      DashboardCard(
                        title: 'Delivery tracking',
                        subtitle: 'Pending & completed deliveries',
                        icon: Icons.local_shipping_outlined,
                        color: Colors.redAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DeliveryTrackingPage(),
                            ),
                          );
                        },
                      ),

                      // ───────────── Row 5 ─────────────
                      DashboardCard(
                        title: 'Staff invites',
                        subtitle: 'Add or remove staff members',
                        icon: Icons.mail_outline,
                        color: Colors.tealAccent,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StaffInvitesPage(),
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

/// Reusable card widget for each dashboard tile.
///
/// Displays an icon badge, title and subtitle, and fires [onTap]
/// when pressed to navigate to the corresponding screen.
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
            // Icon badge
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
            // Title
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade900,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            // Subtitle text
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

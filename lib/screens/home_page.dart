import 'package:flutter/material.dart';

import 'login/volunteer_login.dart';
import 'login/store_login.dart';
import 'login/admin_login.dart';

/// Main public landing page.
///
/// From here users can choose whether they are:
/// - Volunteer
/// - Store / Donor
/// - Staff (link at the bottom)
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen background image
          Image.asset(
            'assets/general_bg.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for better text/card contrast
          Container(color: Colors.black.withOpacity(0.45)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Top title / app name
                  const Text(
                    'FoodLink',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Short tagline / description
                  const Text(
                    'Connecting surplus food with local communities',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),

                  // Spacer pushes role cards toward vertical center
                  const Spacer(),
                  // Volunteer card
                  _RoleCard(
                    title: 'Volunteer',
                    description:
                    'Log donations, manage your profile, and view history.',
                    icon: Icons.volunteer_activism,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const VolunteerLoginPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  // Store / donor card
                  _RoleCard(
                    title: 'Store / Donor',
                    description:
                    'Manage store details and donation information.',
                    icon: Icons.store,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StoreLoginPage(),
                        ),
                      );
                    },
                  ),
                  const Spacer(),

                  // Staff login link at bottom
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AdminLoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      'Are you staff? Log in here',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
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

/// Small reusable card used for each role option on the home page.
///
/// Shows:
/// - leading icon
/// - title
/// - short description
/// - trailing arrow
/// and triggers [onTap] when pressed.
class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.96),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Circular icon badge on the left
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withOpacity(0.10),
              ),
              child: Icon(icon, size: 26, color: Colors.green[700]),
            ),
            const SizedBox(width: 16),
            // Title + description text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role title (e.g. Volunteer)
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Short role description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            // Right arrow icon hinting navigation
            const Icon(Icons.arrow_forward_ios, size: 18),
          ],
        ),
      ),
    );
  }
}

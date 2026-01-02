import 'package:flutter/material.dart';

import 'volunteer_login.dart';
import 'store_login.dart';
import 'admin_login.dart';

/// Entry point login selector screen.
///
/// Lets the user choose whether to log in as:
/// - Volunteer
/// - Store
/// - Staff (admin)
///
/// Each option navigates to its respective login page.
class MyLogin extends StatelessWidget {
  const MyLogin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image covering the full screen
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay to improve contrast for the foreground card
          Container(color: Colors.black.withOpacity(0.45)),
          // Center card with login choices
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title text
                    const Text(
                      'Welcome to FoodLink',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Subtitle / helper text
                    const Text(
                      'Choose how you want to sign in.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 24),

                    // ───────────── Volunteer login button ─────────────
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const VolunteerLoginPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.volunteer_activism),
                        label: const Text('Volunteer login'),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ───────────── Store login button ─────────────
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                              const StoreLoginPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.store),
                        label: const Text('Store login'),
                      ),
                    ),

                    const SizedBox(height: 18),
                    // Divider separating staff login from regular options
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 4),

                    // Subtle staff login text/button at the bottom
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                            const AdminLoginPage(),
                          ),
                        );
                      },
                      child: const Text(
                        'Are you staff? Staff login',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

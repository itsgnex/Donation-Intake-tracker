import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Volunteer screen: show all donations logged by the currently
/// signed-in volunteer.
///
/// - Reads from `donations` where `volunteerId == currentUser.uid`
/// - Sorts results by date (newest first) locally
/// - Displays store name, totals, status and date
class VolunteerViewDonationPage extends StatelessWidget {
  const VolunteerViewDonationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final volunteerId = user?.uid;

    return Scaffold(
      // Match other volunteer screens (dark background + overlay image)
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My donations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for readability
          Container(color: Colors.black.withOpacity(0.55)),

          // ── Main content (same logic as before) ──────────────────────
          if (volunteerId == null)
            const Center(
              child: Text(
                'Not signed in',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              // EXACT SAME QUERY AS BEFORE (no orderBy)
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .where('volunteerId', isEqualTo: volunteerId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No donations logged yet.',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                // SAME LOCAL SORT: by `date` descending (newest first)
                docs.sort((a, b) {
                  final da = (a.data() as Map<String, dynamic>)['date']
                  as Timestamp?;
                  final db = (b.data() as Map<String, dynamic>)['date']
                  as Timestamp?;
                  final ta = da?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final tb = db?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return tb.compareTo(ta);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data =
                    docs[index].data() as Map<String, dynamic>;

                    final storeName =
                    (data['storeName'] ?? '') as String;
                    final totalKg =
                    (data['totalKg'] ?? 0.0).toDouble();
                    final totalBoxes =
                    (data['totalBoxes'] ?? 0) as int;
                    final status =
                    (data['status'] ?? 'pending') as String;
                    final ts = data['date'] as Timestamp?;
                    final date = ts?.toDate();
                    final dateLabel = date == null
                        ? ''
                        : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                    // Card styling updated to match other screens,
                    // but the data shown is identical.
                    return Card(
                      color: Colors.white.withOpacity(0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          storeName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '${totalKg.toStringAsFixed(1)} kg • $totalBoxes boxes\n$status',
                        ),
                        trailing: Text(
                          dateLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

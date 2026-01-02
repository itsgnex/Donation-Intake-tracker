import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Volunteer view: "My schedule"
///
/// - Shows all schedules where this volunteer is assigned
/// - Uses the same Firestore query & sorting as your original code
/// - Only the visual style (colors/layout) has been updated
class VolunteerScheduleViewPage extends StatelessWidget {
  const VolunteerScheduleViewPage({super.key});

  /// Live stream of schedules for the logged-in volunteer.
  /// (Logic unchanged – just commented.)
  Stream<QuerySnapshot> _scheduleStream() {
    final user = AuthService.currentUser;
    final volunteerId = user?.uid;

    if (volunteerId == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('schedules')
        .where('volunteerId', isEqualTo: volunteerId)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    if (user == null) {
      // If somehow reached without being logged in.
      return const Scaffold(
        body: Center(
          child: Text('You must be logged in to view your schedule.'),
        ),
      );
    }

    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      // Match the rest of the volunteer UI
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My schedule',
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
          // Dark overlay so text stays readable
          Container(color: Colors.black.withOpacity(0.55)),

          // Foreground content: original StreamBuilder logic
          StreamBuilder<QuerySnapshot>(
            stream: _scheduleStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading schedule',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No upcoming pickups assigned.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              // Sort by date client-side (no composite index needed).
              // (Same logic as before.)
              docs.sort((a, b) {
                final da = (a['pickupDate'] as Timestamp?)?.toDate();
                final db = (b['pickupDate'] as Timestamp?)?.toDate();
                if (da == null || db == null) return 0;
                return da.compareTo(db);
              });

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data =
                      doc.data() as Map<String, dynamic>? ?? {};

                  final storeName =
                  (data['storeName'] as String? ?? 'Store').trim();
                  final timeWindow =
                  (data['timeWindow'] as String? ?? '').trim();
                  final status =
                  (data['status'] as String? ?? 'scheduled').trim();
                  final ts = data['pickupDate'] as Timestamp?;
                  final dateLabel = ts != null
                      ? _formatDate(ts.toDate())
                      : 'Unknown date';

                  final window = timeWindow.isEmpty ? '-' : timeWindow;

                  // Card style only changed (rounded, soft background).
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: Card(
                      color: Colors.white.withOpacity(0.96),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Store + date/time
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    storeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: $dateLabel',
                                    style: TextStyle(
                                      color: Colors.grey.shade800,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Time: $window',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Status chip on the right
                            Container(
                              margin: const EdgeInsets.only(left: 8, top: 4),
                              child: Chip(
                                label: Text(
                                  status.toLowerCase(),
                                  style: const TextStyle(fontSize: 11),
                                ),
                                backgroundColor:
                                _statusColor(status).withOpacity(0.08),
                                labelStyle: TextStyle(
                                  color: _statusColor(status),
                                  fontWeight: FontWeight.w600,
                                ),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
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

/// Simple helper: convert DateTime -> yyyy-mm-dd string.
String _formatDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// Map schedule status -> a color used for the status chip.
/// Logic is *only* for styling; it does not change any data path.
Color _statusColor(String rawStatus) {
  final s = rawStatus.toLowerCase().trim();
  if (s == 'completed' || s == 'done') return Colors.green;
  if (s == 'cancelled' || s == 'canceled') return Colors.red;
  if (s == 'ready') return Colors.blue;
  return Colors.orange; // default (scheduled / pending / other)
}

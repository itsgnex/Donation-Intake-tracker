import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// --------------------------------------------------------------
/// VolunteerUpcomingAssignmentsPage
/// --------------------------------------------------------------
/// “As a volunteer, I want to view all my upcoming assignments so
/// that I can plan my routes and confirm completion.”
///
/// • Reads from central `schedules` collection
/// • Filters schedules where `volunteerId == currentUser.uid`
/// • Only shows today + future dates (upcoming assignments)
/// • Displays store name, time window, and location
/// • Tapping an item opens a bottom sheet with more details
/// • Includes "Confirm Pickup" and "Confirm Delivery" buttons
/// • Updates Firestore in real-time and logs timestamps
/// --------------------------------------------------------------
class VolunteerUpcomingAssignmentsPage extends StatelessWidget {
  const VolunteerUpcomingAssignmentsPage({super.key});

  /// Live stream of all schedules where this volunteer is assigned.
  Stream<QuerySnapshot> _assignmentStream(String volunteerId) {
    return FirebaseFirestore.instance
        .collection('schedules')
        .where('volunteerId', isEqualTo: volunteerId)
        .snapshots();
  }

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final volunteerId = user?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: const Text(
          'My upcoming assignments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          if (volunteerId == null)
            const Center(
              child: Text(
                'You must be logged in as a volunteer to view assignments.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: _assignmentStream(volunteerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading assignments',
                      style: TextStyle(
                        color: Colors.redAccent.shade100,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                final docsRaw =
                    snapshot.data?.docs.cast<QueryDocumentSnapshot>() ?? [];

                if (docsRaw.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No assignments yet.\nOnce staff assign you to pickups, they will appear here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                // Filter to today + future (upcoming).
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);

                final upcoming = docsRaw.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                  final ts = data['pickupDate'] as Timestamp?;
                  if (ts == null) return false;
                  final d = ts.toDate();
                  final dateOnly = DateTime(d.year, d.month, d.day);
                  return !dateOnly.isBefore(today);
                }).toList();

                if (upcoming.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'You have no upcoming assignments.\nCheck back later.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }

                // Sort ascending by pickup date.
                upcoming.sort((a, b) {
                  final da =
                  (a.data() as Map<String, dynamic>? ?? {})['pickupDate']
                  as Timestamp?;
                  final db =
                  (b.data() as Map<String, dynamic>? ?? {})['pickupDate']
                  as Timestamp?;
                  final ta = da?.toDate() ?? DateTime.now();
                  final tb = db?.toDate() ?? DateTime.now();
                  return ta.compareTo(tb);
                });

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming assignments',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These are your scheduled pickups and deliveries from the central schedule.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView.builder(
                          itemCount: upcoming.length,
                          itemBuilder: (context, index) {
                            final doc = upcoming[index];
                            return _AssignmentCard(
                              doc: doc,
                              formatDate: _formatDate,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Single assignment card with tap for more details + confirm buttons.
class _AssignmentCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String Function(DateTime) formatDate;

  const _AssignmentCard({
    required this.doc,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final data =
        doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};

    final ts = data['pickupDate'] as Timestamp?;
    final storeName = (data['storeName'] as String? ?? '').trim();
    final storeLocation =
    (data['storeLocation'] as String? ?? '').trim();
    final timeWindow = (data['timeWindow'] as String? ?? '').trim();
    final startTime = (data['startTime'] as String? ?? '').trim();
    final endTime = (data['endTime'] as String? ?? '').trim();
    final rawStatus =
    (data['status'] as String? ?? 'scheduled').toString().trim();
    final notes = (data['notes'] as String? ?? '').trim();

    final bool pickupConfirmed =
        (data['pickupConfirmed'] as bool?) ?? false;
    final bool deliveryConfirmed =
        (data['deliveryConfirmed'] as bool?) ?? false;

    DateTime? date;
    String dateLabel = 'Date not set';
    if (ts != null) {
      date = ts.toDate();
      dateLabel = formatDate(date);
    }

    String timeLabel;
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeLabel = '$startTime - $endTime';
    } else if (timeWindow.isNotEmpty) {
      timeLabel = timeWindow;
    } else {
      timeLabel = 'Time not specified';
    }

    final locationLabel =
    storeLocation.isEmpty ? 'Location not specified' : storeLocation;

    // Build status label and color, giving priority to confirm flags.
    Color statusColor;
    String statusText;
    if (deliveryConfirmed) {
      statusColor = Colors.green;
      statusText = 'Delivered';
    } else if (pickupConfirmed) {
      statusColor = Colors.blueAccent;
      statusText = 'Picked up';
    } else {
      switch (rawStatus.toLowerCase()) {
        case 'ready':
          statusColor = Colors.green;
          statusText = 'Ready';
          break;
        case 'completed':
          statusColor = Colors.green;
          statusText = 'Completed';
          break;
        case 'cancelled':
          statusColor = Colors.red;
          statusText = 'Cancelled';
          break;
        default:
          statusColor = Colors.orange;
          statusText = 'Scheduled';
      }
    }

    final storeTitle =
    storeName.isEmpty ? 'Store not set' : storeName;

    return InkWell(
      onTap: () {
        _showDetailsBottomSheet(
          context: context,
          scheduleId: doc.id,
          scheduleData: data,
          storeTitle: storeTitle,
          dateLabel: dateLabel,
          timeLabel: timeLabel,
          locationLabel: locationLabel,
          statusColor: statusColor,
          statusText: statusText,
          notes: notes,
          pickupConfirmed: pickupConfirmed,
          deliveryConfirmed: deliveryConfirmed,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.lightBlueAccent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.route,
                size: 24,
                color: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    storeTitle,
                    style: TextStyle(
                      color: Colors.grey.shade900,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }

  /// Bottom sheet with full details + "Confirm Pickup" / "Confirm Delivery".
  void _showDetailsBottomSheet({
    required BuildContext context,
    required String scheduleId,
    required Map<String, dynamic> scheduleData,
    required String storeTitle,
    required String dateLabel,
    required String timeLabel,
    required String locationLabel,
    required Color statusColor,
    required String statusText,
    required String notes,
    required bool pickupConfirmed,
    required bool deliveryConfirmed,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        Future<void> confirmPickup() async {
          try {
            await FirebaseFirestore.instance
                .collection('schedules')
                .doc(scheduleId)
                .update({
              'pickupConfirmed': true,
              'pickupConfirmedAt': FieldValue.serverTimestamp(),
            });

            // Simple notification for staff
            await FirebaseFirestore.instance
                .collection('notifications')
                .add({
              'type': 'pickup_confirmed',
              'scheduleId': scheduleId,
              'storeId': scheduleData['storeId'] ?? '',
              'volunteerId': scheduleData['volunteerId'] ?? '',
              'timestamp': FieldValue.serverTimestamp(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Pickup confirmed')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to confirm pickup: $e')),
            );
          }
        }

        Future<void> confirmDelivery() async {
          try {
            await FirebaseFirestore.instance
                .collection('schedules')
                .doc(scheduleId)
                .update({
              'deliveryConfirmed': true,
              'deliveryConfirmedAt': FieldValue.serverTimestamp(),
              // Mark as completed so staff & stores see it as done
              'status': 'completed',
            });

            await FirebaseFirestore.instance
                .collection('notifications')
                .add({
              'type': 'delivery_confirmed',
              'scheduleId': scheduleId,
              'storeId': scheduleData['storeId'] ?? '',
              'volunteerId': scheduleData['volunteerId'] ?? '',
              'timestamp': FieldValue.serverTimestamp(),
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Delivery confirmed')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to confirm delivery: $e')),
            );
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storeTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.event, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      timeLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.place_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        locationLabel,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Notes for this assignment:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes.isEmpty
                      ? 'No additional notes provided.'
                      : notes,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                // Confirm buttons row
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: pickupConfirmed
                            ? null
                            : () async {
                          await confirmPickup();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          pickupConfirmed
                              ? 'Pickup confirmed'
                              : 'Confirm pickup',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (!pickupConfirmed || deliveryConfirmed)
                            ? null
                            : () async {
                          await confirmDelivery();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.local_shipping_outlined),
                        label: Text(
                          deliveryConfirmed
                              ? 'Delivery confirmed'
                              : 'Confirm delivery',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

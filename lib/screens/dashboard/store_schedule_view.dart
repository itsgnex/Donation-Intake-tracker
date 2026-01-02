import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// StorePickupSchedule / StoreScheduleViewPage
///
/// Shown to STORE users. Lists all their pickup schedules and
/// highlights the next upcoming pickup at the top.
class StoreScheduleViewPage extends StatelessWidget {
  const StoreScheduleViewPage({super.key});

  /// Live stream of schedules for the currently logged-in store.
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

  /// Format Timestamp to YYYY-MM-DD.
  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Build a human readable time window.
  String _formatTimeWindow(Map<String, dynamic> data) {
    final startTime = (data['startTime'] as String? ?? '').trim();
    final endTime = (data['endTime'] as String? ?? '').trim();
    final timeWindow = (data['timeWindow'] as String? ?? '').trim();

    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime - $endTime';
    }
    if (timeWindow.isNotEmpty) return timeWindow;
    return 'Time not set';
  }

  /// Status -> chip color + label.
  (Color, String) _statusInfo(Map<String, dynamic> data) {
    final statusRaw =
    (data['status'] as String? ?? 'scheduled').toLowerCase().trim();

    if (statusRaw == 'completed') {
      return (Colors.green, 'Completed');
    }
    if (statusRaw == 'ready') {
      return (Colors.green.shade600, 'Ready');
    }
    if (statusRaw == 'cancelled') {
      return (Colors.red, 'Cancelled');
    }
    return (Colors.orange, 'Scheduled');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // match store dashboard background
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Pickup schedule',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // same background image as dashboard
          Image.asset(
            'assets/store_bg.jpg',
            fit: BoxFit.cover,
          ),
          // dark overlay so cards pop
          Container(color: Colors.black.withOpacity(0.55)),

          // main content
          StreamBuilder<QuerySnapshot>(
            stream: _storeSchedulesStream(),
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
                    'Could not load schedules',
                    style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              final docs =
                  snapshot.data?.docs.cast<QueryDocumentSnapshot>() ?? [];

              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No pickups scheduled yet.\n'
                          'Staff will assign pickups to this store.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              // Sort ascending by pickupDate.
              docs.sort((a, b) {
                final da = (a.data()
                as Map<String, dynamic>? ??
                    {})['pickupDate'] as Timestamp?;
                final db = (b.data()
                as Map<String, dynamic>? ??
                    {})['pickupDate'] as Timestamp?;
                final ta =
                    da?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                final tb =
                    db?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                return ta.compareTo(tb);
              });

              // Determine "next pickup" (today or future).
              final now = DateTime.now();
              final todayOnly = DateTime(now.year, now.month, now.day);
              QueryDocumentSnapshot? nextPickupDoc;

              for (final doc in docs) {
                final data =
                    doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                final ts = data['pickupDate'] as Timestamp?;
                if (ts == null) continue;
                final d = ts.toDate();
                final dateOnly = DateTime(d.year, d.month, d.day);
                if (!dateOnly.isBefore(todayOnly)) {
                  nextPickupDoc = doc;
                  break;
                }
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (nextPickupDoc != null)
                    _NextPickupCard(
                      data: nextPickupDoc!.data()
                      as Map<String, dynamic>? ??
                          <String, dynamic>{},
                      formatDate: _formatDate,
                      formatTimeWindow: _formatTimeWindow,
                      statusInfo: _statusInfo,
                    ),
                  if (nextPickupDoc != null) const SizedBox(height: 8),

                  // All pickups list
                  ...docs.map(
                        (doc) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: _ScheduleCard(
                        data: doc.data()
                        as Map<String, dynamic>? ??
                            <String, dynamic>{},
                        formatDate: _formatDate,
                        formatTimeWindow: _formatTimeWindow,
                        statusInfo: _statusInfo,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Big highlighted card for the next upcoming pickup.
class _NextPickupCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(Timestamp) formatDate;
  final String Function(Map<String, dynamic>) formatTimeWindow;
  final (Color, String) Function(Map<String, dynamic>) statusInfo;

  const _NextPickupCard({
  required this.data,
  required this.formatDate,
  required this.formatTimeWindow,
  required this.statusInfo,
  });

  @override
  Widget build(BuildContext context) {
  final pickupTs = data['pickupDate'] as Timestamp?;
  final dateLabel =
  pickupTs == null ? 'Date not set' : formatDate(pickupTs);
  final timeLabel = formatTimeWindow(data);

  final volunteerName =
  (data['volunteerName'] as String? ?? '').trim();
  final volunteerEmail =
  (data['volunteerEmail'] as String? ?? '').trim();

  final (statusColor, statusText) = statusInfo(data);

  final avatarLetter =
  (volunteerName.isNotEmpty ? volunteerName[0] : 'V').toUpperCase();

  return Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.97),
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
  BoxShadow(
  color: Colors.black.withOpacity(0.18),
  blurRadius: 8,
  offset: const Offset(0, 4),
  ),
  ],
  ),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  // Title + status chip
  Row(
  children: [
  const Icon(Icons.event, size: 22, color: Colors.black87),
  const SizedBox(width: 8),
  const Text(
  'Next pickup',
  style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: Colors.black87,
  ),
  ),
  const Spacer(),
  Container(
  padding:
  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
  color: statusColor.withOpacity(0.10),
  borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
  statusText,
  style: TextStyle(
  color: statusColor,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  ),
  ),
  ),
  ],
  ),
  const SizedBox(height: 10),
  Text(
  dateLabel,
  style: const TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  ),
  ),
  const SizedBox(height: 2),
  Text(
  timeLabel,
  style: TextStyle(
  fontSize: 13,
  color: Colors.grey.shade700,
  ),
  ),
  const SizedBox(height: 12),
  Row(
  children: [
  CircleAvatar(
  radius: 18,
  backgroundColor: Colors.grey.shade200,
  child: Text(
  avatarLetter,
  style: const TextStyle(
  fontWeight: FontWeight.bold,
  color: Colors.black87,
  ),
  ),
  ),
  const SizedBox(width: 10),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  volunteerName.isEmpty
  ? 'Volunteer not set'
      : volunteerName,
  style: const TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  ),
  ),
  const SizedBox(height: 2),
  if (volunteerEmail.isNotEmpty)
  Row(
  children: [
  const Icon(
  Icons.email_outlined,
  size: 14,
  color: Colors.black54,
  ),
  const SizedBox(width: 4),
  Expanded(
  child: Text(
  volunteerEmail,
  style: const TextStyle(
  fontSize: 12,
  color: Colors.black54,
  ),
  overflow: TextOverflow.ellipsis,
  ),
  ),
  ],
  ),
  ],
  ),
  ),
  ],
  ),
  ],
  ),
  );
  }
}

/// Standard schedule card for each pickup in the list.
class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String Function(Timestamp) formatDate;
  final String Function(Map<String, dynamic>) formatTimeWindow;
  final (Color, String) Function(Map<String, dynamic>) statusInfo;

  const _ScheduleCard({
  required this.data,
  required this.formatDate,
  required this.formatTimeWindow,
  required this.statusInfo,
  });

  @override
  Widget build(BuildContext context) {
  final pickupTs = data['pickupDate'] as Timestamp?;
  final dateLabel =
  pickupTs == null ? 'Date not set' : formatDate(pickupTs);
  final timeLabel = formatTimeWindow(data);

  final volunteerName =
  (data['volunteerName'] as String? ?? '').trim();
  final volunteerEmail =
  (data['volunteerEmail'] as String? ?? '').trim();
  final location =
  (data['storeLocation'] as String? ?? 'Location not set').trim();

  final (statusColor, statusText) = statusInfo(data);

  final avatarLetter =
  (volunteerName.isNotEmpty ? volunteerName[0] : 'V').toUpperCase();

  return Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.96),
  borderRadius: BorderRadius.circular(22),
  boxShadow: [
  BoxShadow(
  color: Colors.black.withOpacity(0.15),
  blurRadius: 6,
  offset: const Offset(0, 3),
  ),
  ],
  ),
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  // date + status chip
  Row(
  children: [
  Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  dateLabel,
  style: const TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  ),
  ),
  const SizedBox(height: 2),
  Text(
  timeLabel,
  style: TextStyle(
  fontSize: 13,
  color: Colors.grey.shade700,
  ),
  ),
  const SizedBox(height: 2),
  Text(
  'Location: $location',
  style: TextStyle(
  fontSize: 12,
  color: Colors.grey.shade600,
  ),
  ),
  ],
  ),
  const Spacer(),
  Container(
  padding:
  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
  color: statusColor.withOpacity(0.10),
  borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
  statusText,
  style: TextStyle(
  color: statusColor,
  fontSize: 11,
  fontWeight: FontWeight.w600,
  ),
  ),
  ),
  ],
  ),
  const SizedBox(height: 10),
  Row(
  children: [
  CircleAvatar(
  radius: 18,
  backgroundColor: Colors.grey.shade200,
  child: Text(
  avatarLetter,
  style: const TextStyle(
  fontWeight: FontWeight.bold,
  color: Colors.black87,
  ),
  ),
  ),
  const SizedBox(width: 10),
  Expanded(
  child: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  volunteerName.isEmpty
  ? 'Volunteer not set'
      : volunteerName,
  style: const TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  ),
  ),
  const SizedBox(height: 2),
  if (volunteerEmail.isNotEmpty)
  Row(
  children: [
  const Icon(
  Icons.email_outlined,
  size: 14,
  color: Colors.black54,
  ),
  const SizedBox(width: 4),
  Expanded(
  child: Text(
  volunteerEmail,
  style: const TextStyle(
  fontSize: 12,
  color: Colors.black54,
  ),
  overflow: TextOverflow.ellipsis,
  ),
  ),
  ],
  ),
  ],
  ),
  ),
  ],
  ),
  ],
  ),
  );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// ConfirmReadinessPage  (STORE side)
/// ---------------------------------------------------------------------------
/// Shown to a **store user** so they can confirm that food will be ready
/// for upcoming pickups.
///
/// • Reads the store’s schedules from `schedules` collection
/// • Only shows **today and future** pickups
/// • If status == 'ready' → shows "Already confirmed" pill (disabled)
/// • Otherwise → "Confirm ready" pill button
/// • When confirming:
///     - updates schedule: status = 'ready', readyConfirmedAt = serverTimestamp
///     - optionally creates a doc in `notifications` collection so staff /
///       volunteer can be notified.
/// ---------------------------------------------------------------------------
class ConfirmReadinessPage extends StatefulWidget {
  const ConfirmReadinessPage({super.key});

  @override
  State<ConfirmReadinessPage> createState() => _ConfirmReadinessPageState();
}

class _ConfirmReadinessPageState extends State<ConfirmReadinessPage> {
  /// Used to avoid double-tapping multiple cards while one update is in flight.
  bool _saving = false;

  /// Stream of schedules for the currently logged-in store.
  Stream<QuerySnapshot> _scheduleStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('schedules')
        .where('storeId', isEqualTo: uid)
        .snapshots();
  }

  /// Format a Firestore Timestamp to YYYY-MM-DD.
  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Mark this schedule as "ready" and send a notification.
  Future<void> _confirmSchedule(QueryDocumentSnapshot doc) async {
    // Don't allow multiple overlapping saves.
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    final data = doc.data() as Map<String, dynamic>? ?? {};
    final volunteerId = data['volunteerId'] as String?;
    final volunteerName = data['volunteerName'] as String? ?? '';
    final storeId = data['storeId'] as String? ?? '';
    final storeName = data['storeName'] as String? ?? '';

    try {
      // Update schedule status.
      await doc.reference.update({
        'status': 'ready',
        'readyConfirmedAt': FieldValue.serverTimestamp(),
      });

      // Optional: create a notification so volunteers/staff can see it.
      if (volunteerId != null && volunteerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('notifications').add({
          'type': 'readiness_confirmed',
          'scheduleId': doc.id,
          'storeId': storeId,
          'storeName': storeName,
          'volunteerId': volunteerId,
          'volunteerName': volunteerName,
          'createdAt': FieldValue.serverTimestamp(),
          'message':
          'Store $storeName has confirmed that the donation will be ready.',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Readiness confirmed for this pickup.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Failed to confirm readiness. Please try again later.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match store dashboard background
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Confirm Readiness',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same as other store screens)
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay so white cards stand out
          Container(color: Colors.black.withOpacity(0.55)),

          // Main content
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
                return Center(
                  child: Text(
                    'Failed to load schedules',
                    style: TextStyle(
                      color: Colors.red.shade200,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              final now = DateTime.now();
              final todayOnly = DateTime(now.year, now.month, now.day);

              // Only keep today and future schedules.
              final docs = (snapshot.data?.docs ?? []).where((doc) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                final ts = data['pickupDate'] as Timestamp?;
                if (ts == null) return false;
                final d = ts.toDate();
                final dateOnly = DateTime(d.year, d.month, d.day);
                return dateOnly.isAtSameMomentAs(todayOnly) ||
                    dateOnly.isAfter(todayOnly);
              }).toList();

              // Sort by pickup date ascending (earlier first).
              docs.sort((a, b) {
                final ad =
                (a.data() as Map<String, dynamic>? ?? {})['pickupDate']
                as Timestamp?;
                final bd =
                (b.data() as Map<String, dynamic>? ?? {})['pickupDate']
                as Timestamp?;
                final ta = ad?.toDate() ?? DateTime(2100);
                final tb = bd?.toDate() ?? DateTime(2100);
                return ta.compareTo(tb);
              });

              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No upcoming schedules to confirm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>? ?? {};

                  final ts = data['pickupDate'] as Timestamp?;
                  final startTime = (data['startTime'] as String? ?? '').trim();
                  final endTime = (data['endTime'] as String? ?? '').trim();
                  final timeWindow =
                  (data['timeWindow'] as String? ?? '').trim();
                  final volunteerName =
                  (data['volunteerName'] as String? ?? '').trim();
                  final status =
                  (data['status'] as String? ?? 'scheduled').trim();

                  final dateText = ts == null ? 'No date' : _formatDate(ts);

                  String timeText;
                  if (startTime.isNotEmpty && endTime.isNotEmpty) {
                    timeText = '$dateText • $startTime - $endTime';
                  } else if (timeWindow.isNotEmpty) {
                    timeText = '$dateText • $timeWindow';
                  } else {
                    timeText = dateText;
                  }

                  final volunteerDisplay = volunteerName.isEmpty
                      ? 'Volunteer: Unassigned'
                      : 'Volunteer: $volunteerName';

                  final statusDisplay =
                  status == 'ready' ? 'Status: Ready' : 'Status: Scheduled';

                  final alreadyReady = status == 'ready';

                  return _ConfirmCard(
                    timeText: timeText,
                    volunteerDisplay: volunteerDisplay,
                    statusDisplay: statusDisplay,
                    alreadyReady: alreadyReady,
                    saving: _saving,
                    onConfirm: () => _confirmSchedule(doc),
                  );
                },
              );
            },
          ),

          // Small loading bar at very top when saving (optional but nice UX)
          if (_saving)
            const Align(
              alignment: Alignment.topCenter,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// _ConfirmCard
/// ---------------------------------------------------------------------------
/// Pretty, themed card for a single schedule row.
/// Shows date/time + volunteer + status + pill-shaped confirm button.
/// ---------------------------------------------------------------------------
class _ConfirmCard extends StatelessWidget {
  final String timeText;
  final String volunteerDisplay;
  final String statusDisplay;
  final bool alreadyReady;
  final bool saving;
  final VoidCallback onConfirm;

  const _ConfirmCard({
    required this.timeText,
    required this.volunteerDisplay,
    required this.statusDisplay,
    required this.alreadyReady,
    required this.saving,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    // Colors for the pill button.
    final Color accentGreen = Colors.green;
    final bool disabled = alreadyReady || saving;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time + pill button row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date/time text
              Expanded(
                child: Text(
                  timeText,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Pill button
              ElevatedButton(
                onPressed: disabled ? null : onConfirm,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  backgroundColor:
                  alreadyReady ? Colors.grey.shade300 : Colors.white,
                  foregroundColor:
                  alreadyReady ? Colors.grey.shade600 : accentGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: alreadyReady
                          ? Colors.grey.shade300
                          : accentGreen.withOpacity(0.4),
                    ),
                  ),
                ),
                child: Text(
                  alreadyReady ? 'Already confirmed' : 'Confirm ready',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            volunteerDisplay,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusDisplay,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

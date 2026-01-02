import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// ===================================================================
/// DeliveryTrackingPage (Staff)
/// -------------------------------------------------------------------
/// Story 30:
/// “As staff, I want to track pending and completed deliveries so that
/// I can monitor overall progress.”
///
/// - Reads from central `schedules` collection
/// - Pending = not cancelled and not completed/deliveryConfirmed
/// - Completed = `deliveryConfirmed == true` OR `status == 'completed'`
/// - Shows two dashboard widgets (Pending / Completed) with live counts
/// - Shows a filterable list of all deliveries
/// - Filter by Store name or Volunteer name
/// - Displays completion time if available (`deliveryConfirmedAt`)
/// ===================================================================
class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({super.key});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  String? _selectedStore;
  String? _selectedVolunteer;

  /// Live stream of all schedules.
  Stream<QuerySnapshot> _schedulesStream() {
    return FirebaseFirestore.instance.collection('schedules').snapshots();
  }

  /// Format a DateTime as YYYY-MM-DD HH:mm
  String _formatDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }

  /// A schedule is considered completed if either:
  /// - deliveryConfirmed == true
  /// - OR status == 'completed'
  bool _isCompleted(Map<String, dynamic> data) {
    final bool deliveryConfirmed =
        (data['deliveryConfirmed'] as bool?) ?? false;
    final String status =
    (data['status'] as String? ?? 'scheduled').toLowerCase().trim();
    return deliveryConfirmed || status == 'completed';
  }

  /// Cancelled if status == 'cancelled'
  bool _isCancelled(Map<String, dynamic> data) {
    final String status =
    (data['status'] as String? ?? '').toLowerCase().trim();
    return status == 'cancelled';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      /// ----------------------------------------------------------------
      /// APP BAR
      /// - Keep background transparent so we see the image
      /// - Set iconTheme to white so the back arrow is **visible**
      ///   (no big circle, just a white arrow)
      /// ----------------------------------------------------------------
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white, // 👈 makes back arrow / icons white
        ),
        title: const Text(
          'Delivery tracking',
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

          // Main content
          StreamBuilder<QuerySnapshot>(
            stream: _schedulesStream(),
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
                    'Error loading deliveries',
                    style: TextStyle(
                      color: Colors.redAccent.shade100,
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
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No deliveries found.\nSchedules will appear here as they are created.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              // ===== Summary counts across all schedules =====
              int pendingCount = 0;
              int completedCount = 0;

              for (final doc in docs) {
                final data =
                    doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                if (_isCancelled(data)) continue;
                if (_isCompleted(data)) {
                  completedCount++;
                } else {
                  pendingCount++;
                }
              }

              // ===== Distinct store + volunteer names for filters =====
              final Set<String> storeNames = {};
              final Set<String> volunteerNames = {};

              for (final doc in docs) {
                final data =
                    doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                final storeName =
                (data['storeName'] as String? ?? '').trim();
                final volunteerName =
                (data['volunteerName'] as String? ?? '').trim();
                if (storeName.isNotEmpty) storeNames.add(storeName);
                if (volunteerName.isNotEmpty) {
                  volunteerNames.add(volunteerName);
                }
              }

              // ===== Apply dropdown filters =====
              final filteredDocs = docs.where((doc) {
                final data =
                    doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                final storeName =
                (data['storeName'] as String? ?? '').trim();
                final volunteerName =
                (data['volunteerName'] as String? ?? '').trim();

                if (_selectedStore != null &&
                    _selectedStore!.isNotEmpty &&
                    storeName != _selectedStore) {
                  return false;
                }

                if (_selectedVolunteer != null &&
                    _selectedVolunteer!.isNotEmpty &&
                    volunteerName != _selectedVolunteer) {
                  return false;
                }

                return true;
              }).toList();

              // Sort by pickupDate DESC (most recent first).
              filteredDocs.sort((a, b) {
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
                return tb.compareTo(ta);
              });

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === TOP CARD: header + summary + filters on solid white ===
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Delivery overview',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Monitor pending and completed deliveries in real time.',
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // === Summary widgets (Pending / Completed) ===
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  title: 'Pending deliveries',
                                  count: pendingCount,
                                  color: Colors.orangeAccent,
                                  icon: Icons.local_shipping_outlined,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  title: 'Completed deliveries',
                                  count: completedCount,
                                  color: Colors.greenAccent,
                                  icon: Icons.check_circle_outline,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // === Filters row ===
                          Row(
                            children: [
                              // Filter by store
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedStore ?? '',
                                  decoration: InputDecoration(
                                    labelText: 'Filter by store',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('All stores'),
                                    ),
                                    ...storeNames.map(
                                          (name) => DropdownMenuItem<String>(
                                        value: name,
                                        child: Text(name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedStore =
                                      (val == null || val.isEmpty)
                                          ? null
                                          : val;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Filter by volunteer
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedVolunteer ?? '',
                                  decoration: InputDecoration(
                                    labelText: 'Filter by volunteer',
                                    labelStyle: const TextStyle(fontSize: 12),
                                    filled: true,
                                    fillColor: Colors.grey.shade100,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding:
                                    const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: '',
                                      child: Text('All volunteers'),
                                    ),
                                    ...volunteerNames.map(
                                          (name) => DropdownMenuItem<String>(
                                        value: name,
                                        child: Text(name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedVolunteer =
                                      (val == null || val.isEmpty)
                                          ? null
                                          : val;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedStore = null;
                                  _selectedVolunteer = null;
                                });
                              },
                              child: const Text('Reset filters'),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    const Text(
                      'All deliveries',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // === LIST OF DELIVERIES ===
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ??
                                  <String, dynamic>{};
                          return _DeliveryListItem(
                            data: data,
                            isCompleted: _isCompleted(data),
                            isCancelled: _isCancelled(data),
                            formatDateTime: _formatDateTime,
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

/// Small summary widget card for counts.
class _SummaryCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // icon chip
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: color.withOpacity(0.95),
            ),
          ),
          const SizedBox(width: 10),
          // text & count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color.withOpacity(0.95),
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

/// Single delivery row in the list.
class _DeliveryListItem extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isCompleted;
  final bool isCancelled;
  final String Function(DateTime) formatDateTime;

  const _DeliveryListItem({
    required this.data,
    required this.isCompleted,
    required this.isCancelled,
    required this.formatDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final storeName = (data['storeName'] as String? ?? '').trim();
    final volunteerName = (data['volunteerName'] as String? ?? '').trim();
    final storeLocation = (data['storeLocation'] as String? ?? '').trim();
    final timeWindow = (data['timeWindow'] as String? ?? '').trim();
    final startTime = (data['startTime'] as String? ?? '').trim();
    final endTime = (data['endTime'] as String? ?? '').trim();
    final statusRaw =
    (data['status'] as String? ?? 'scheduled').toLowerCase().trim();

    final pickupTs = data['pickupDate'] as Timestamp?;
    final deliveryConfirmedAtTs =
    data['deliveryConfirmedAt'] as Timestamp?;

    // ----- Date + time labels -----
    String dateLabel = 'Date not set';
    if (pickupTs != null) {
      final d = pickupTs.toDate();
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      dateLabel = '$y-$m-$day';
    }

    String timeLabel;
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      timeLabel = '$startTime - $endTime';
    } else if (timeWindow.isNotEmpty) {
      timeLabel = timeWindow;
    } else {
      timeLabel = 'Time not specified';
    }

    // ----- Completion info -----
    String completionInfo = 'Not delivered yet';
    if (deliveryConfirmedAtTs != null) {
      final dt = deliveryConfirmedAtTs.toDate();
      completionInfo = 'Delivered at ${formatDateTime(dt)}';
    }

    // ----- Status chip -----
    Color statusColor;
    String statusText;

    if (isCancelled) {
      statusColor = Colors.red;
      statusText = 'Cancelled';
    } else if (isCompleted) {
      statusColor = Colors.green;
      statusText = 'Completed';
    } else {
      statusColor = Colors.orange;
      statusText = 'Pending';
    }

    final locationLabel =
    storeLocation.isEmpty ? 'Location not set' : storeLocation;

    final storeTitle =
    storeName.isEmpty ? 'Store not set' : storeName;

    final volunteerLabel = volunteerName.isEmpty
        ? 'Volunteer: not assigned'
        : 'Volunteer: $volunteerName';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // First row: store + status chip
          Row(
            children: [
              Expanded(
                child: Text(
                  storeTitle,
                  style: TextStyle(
                    color: Colors.grey.shade900,
                    fontSize: 14,
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
                  color: statusColor.withOpacity(0.14),
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
          const SizedBox(height: 4),
          Text(
            '$dateLabel • $timeLabel',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
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
          const SizedBox(height: 4),
          Text(
            volunteerLabel,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            completionInfo,
            style: TextStyle(
              fontSize: 11,
              color: statusRaw == 'completed'
                  ? Colors.green.shade700
                  : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

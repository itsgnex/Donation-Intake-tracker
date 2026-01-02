import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';

/// Volunteer screen: "Recent activity"
///
/// - Shows donations for the logged-in volunteer
/// - Can sort by newest, oldest, or by category
/// - Uses the same query + sorting logic as your original version,
///   only the visuals (theme) have been updated.
class VolunteerRecentDonationsPage extends StatefulWidget {
  const VolunteerRecentDonationsPage({super.key});

  @override
  State<VolunteerRecentDonationsPage> createState() =>
      _VolunteerRecentDonationsPageState();
}

class _VolunteerRecentDonationsPageState
    extends State<VolunteerRecentDonationsPage> {
  /// Sort mode for the dropdown: 'newest', 'oldest', or 'category'.
  String _sortMode = 'newest';

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;
    final String? volunteerId = user?.uid;

    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      // Match other volunteer screens (dark background + image)
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
      body: volunteerId == null
          ? const Center(
        child: Text(
          'Not signed in',
          style: TextStyle(color: Colors.white),
        ),
      )
          : Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for readability
          Container(color: Colors.black.withOpacity(0.55)),

          // ── Foreground content ───────────────────────────
          Column(
            children: [
              // ── Sort bar (top) ───────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text(
                      'Sort by:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: _sortMode,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(12),
                      items: const [
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Newest first'),
                        ),
                        DropdownMenuItem(
                          value: 'oldest',
                          child: Text('Oldest first'),
                        ),
                        DropdownMenuItem(
                          value: 'category',
                          child: Text('Category'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _sortMode = value;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 0),

              // ── Donation list (same logic as before) ─────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  // Filter by volunteerId written on each donation
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

                    List<QueryDocumentSnapshot> docs =
                        snapshot.data?.docs
                            .cast<QueryDocumentSnapshot>() ??
                            [];

                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No donations found for this account.',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    // ----- sorting (unchanged logic) -----
                    docs.sort((a, b) {
                      final Map<String, dynamic> da =
                      a.data() as Map<String, dynamic>;
                      final Map<String, dynamic> db =
                      b.data() as Map<String, dynamic>;
                      final Timestamp? dtsA =
                      da['date'] as Timestamp?;
                      final Timestamp? dtsB =
                      db['date'] as Timestamp?;
                      final DateTime ta = dtsA?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final DateTime tb = dtsB?.toDate() ??
                          DateTime.fromMillisecondsSinceEpoch(0);

                      if (_sortMode == 'oldest') {
                        return ta.compareTo(tb); // oldest first
                      }

                      if (_sortMode == 'category') {
                        final String ca =
                        (da['category'] ?? '') as String;
                        final String cb =
                        (db['category'] ?? '') as String;
                        final String caLower = ca.toLowerCase();
                        final String cbLower = cb.toLowerCase();
                        final int cmp = caLower.compareTo(cbLower);
                        if (cmp != 0) return cmp;
                        // if same category, keep newest first
                        return tb.compareTo(ta);
                      }

                      // default: newest first
                      return tb.compareTo(ta);
                    });

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final Map<String, dynamic> data =
                        docs[index].data()
                        as Map<String, dynamic>;

                        final String storeName =
                        (data['storeName'] ?? '') as String;
                        final double totalKg =
                        (data['totalKg'] ?? 0.0).toDouble();
                        final int totalBoxes =
                        (data['totalBoxes'] ?? 0) as int;
                        final Timestamp? ts =
                        data['date'] as Timestamp?;
                        final String category =
                        (data['category'] ?? '') as String;
                        final String status =
                        (data['status'] ?? 'pending') as String;

                        final DateTime? date = ts?.toDate();
                        final String dateLabel = date == null
                            ? ''
                            : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                        final String categoryLabel = category.isEmpty
                            ? 'Uncategorized'
                            : category;

                        // Card styling only: rounded card with
                        // light background like other screens.
                        return Card(
                          color: Colors.white.withOpacity(0.96),
                          margin:
                          const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                              color.primary.withOpacity(0.08),
                              child: Text(
                                (storeName.isNotEmpty
                                    ? storeName[0]
                                    : '?')
                                    .toUpperCase(),
                                style: TextStyle(
                                  color: color.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              storeName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  categoryLabel,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${totalKg.toStringAsFixed(1)} kg • $totalBoxes boxes',
                                ),
                                const SizedBox(height: 4),
                                _buildStatusChip(status),
                              ],
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build a small coloured status chip (Approved / Declined / Pending).
  ///
  /// The logic for mapping `rawStatus` to label + colour is exactly the
  /// same as your original implementation.
  Widget _buildStatusChip(String rawStatus) {
    final String status = rawStatus.toLowerCase().trim();

    Color baseColor;
    String label;

    if (status == 'approved' ||
        status == 'accepted' ||
        status == 'completed') {
      baseColor = Colors.green;
      label = 'Approved';
    } else if (status == 'rejected' || status == 'declined') {
      baseColor = Colors.red;
      label = 'Declined';
    } else if (status == 'pending') {
      baseColor = Colors.orange;
      label = 'Pending';
    } else {
      baseColor = Colors.grey;
      label = rawStatus.isEmpty ? 'Unknown' : rawStatus;
    }

    return Container(
      margin: const EdgeInsets.only(top: 2),
      child: Chip(
        label: Text(
          label,
          style: const TextStyle(fontSize: 11),
        ),
        backgroundColor: baseColor.withOpacity(0.12),
        labelStyle: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.w600,
        ),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

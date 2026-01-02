import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Analytics / Coverage dashboard for staff.
///
/// This screen shows high-level coverage information built from:
/// - `stores` collection  (all stores the org knows about)
/// - `schedules` collection (pickup schedules per store)
///
/// Simple logic:
///  - A store is considered "covered" if there is at least one schedule
///    document whose `storeId` matches that store's document id.
///  - Otherwise it is "not covered".
class AnalyticsDashboardPage extends StatefulWidget {
  const AnalyticsDashboardPage({super.key});

  @override
  State<AnalyticsDashboardPage> createState() =>
      _AnalyticsDashboardPageState();
}

class _AnalyticsDashboardPageState extends State<AnalyticsDashboardPage> {
  // Firestore handle.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Loading / error state for the dashboard.
  bool _loading = true;
  String? _errorMessage;

  // Raw data loaded from Firestore.
  List<QueryDocumentSnapshot> _storeDocs = [];
  List<QueryDocumentSnapshot> _scheduleDocs = [];

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load stores and schedules from Firestore in parallel.
  ///
  /// NOTE: This only reads; it does not modify any data.
  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      // Fetch stores and schedules in parallel.
      final results = await Future.wait([
        _firestore.collection('stores').get(),
        _firestore.collection('schedules').get(),
      ]);

      if (!mounted) return;

      setState(() {
        _storeDocs = results[0].docs;
        _scheduleDocs = results[1].docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'Failed to load analytics data.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading analytics: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Derived metrics (logic unchanged)
  // ---------------------------------------------------------------------------

  /// Build a map of storeId → number of schedules attached to that store.
  Map<String, int> _buildStoreScheduleCounts() {
    final Map<String, int> counts = {};
    for (final doc in _scheduleDocs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final storeId = (data['storeId'] ?? '').toString();
      if (storeId.isEmpty) continue;
      counts[storeId] = (counts[storeId] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Basic counts derived from Firestore data.
    final storeScheduleCounts = _buildStoreScheduleCounts();
    final totalStores = _storeDocs.length;
    final coveredStores =
        _storeDocs.where((s) => storeScheduleCounts.containsKey(s.id)).length;
    final uncoveredStores = totalStores - coveredStores;

    final totalSchedules = _scheduleDocs.length;

    // Unique volunteer IDs found in schedules.
    final uniqueVolunteerIds = <String>{};
    for (final doc in _scheduleDocs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final vId = (data['volunteerId'] ?? '').toString();
      if (vId.isNotEmpty) uniqueVolunteerIds.add(vId);
    }

    return Scaffold(
      // Black background like the Delivery tracking page.
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Analytics Dashboard',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Use a Stack to mirror the Delivery tracking layout:
      // 1) photo background
      // 2) dark overlay
      // 3) scrollable analytics content
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same asset used on the staff dashboard / delivery).
          Image.asset(
            'assets/staff_bg.jpg',
            fit: BoxFit.cover,
          ),

          // Semi-transparent black overlay to keep cards readable.
          Container(color: Colors.black.withOpacity(0.5)),

          // Foreground: loading / error / analytics content.
          if (_loading)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_errorMessage != null)
            Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.white),
              ),
            )
          else
          // Pull-to-refresh around the analytics list.
            RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  // ───────────────── Overview card ─────────────────
                  Card(
                    elevation: 6,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Coverage overview',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Quick view of stores and schedules.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _overviewChip(
                                label: 'Total stores',
                                value: totalStores.toString(),
                              ),
                              const SizedBox(width: 8),
                              _overviewChip(
                                label: 'Covered',
                                value: coveredStores.toString(),
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              _overviewChip(
                                label: 'Uncovered',
                                value: uncoveredStores.toString(),
                                color: Colors.red,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _smallMetric(
                                icon: Icons.event_available,
                                label: 'Total schedules',
                                value: totalSchedules.toString(),
                              ),
                              const SizedBox(width: 12),
                              _smallMetric(
                                icon: Icons.group_outlined,
                                label: 'Active volunteers',
                                value: uniqueVolunteerIds.length.toString(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ───────────────── Per-store coverage list ─────────────────
                  Text(
                    'Store coverage',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (totalStores == 0)
                    const Text(
                      'No stores found in the database.',
                      style: TextStyle(color: Colors.white),
                    )
                  else
                    ..._storeDocs.map((storeDoc) {
                      final data =
                          storeDoc.data() as Map<String, dynamic>? ?? {};
                      final storeName =
                      (data['storeName'] ?? 'Unnamed store').toString();
                      final location =
                      (data['address'] ?? data['suburb'] ?? '').toString();
                      final scheduleCount =
                          storeScheduleCounts[storeDoc.id] ?? 0;
                      final covered = scheduleCount > 0;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        color: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          title: Text(
                            storeName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (location.isNotEmpty)
                                Text(
                                  location,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              Text(
                                '$scheduleCount schedule(s)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          trailing: _coverageStatusChip(covered),
                        ),
                      );
                    }).toList(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small UI helpers (visual only, no business logic changed)
  // ---------------------------------------------------------------------------

  /// Overview chip used at the top of the page, e.g. "Total stores", "Covered".
  Widget _overviewChip({
    required String label,
    required String value,
    Color? color,
  }) {
    final c = color ?? Colors.grey.shade800;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: c.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Secondary metric row: icon + label + value.
  Widget _smallMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.black.withOpacity(0.04),
            ),
            child: Icon(icon, size: 18),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Chip showing whether a store is covered or not.
  Widget _coverageStatusChip(bool covered) {
    final color = covered ? Colors.green : Colors.orange;
    final label = covered ? 'Covered' : 'No schedules';

    return Chip(
      backgroundColor: color.withOpacity(0.12),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

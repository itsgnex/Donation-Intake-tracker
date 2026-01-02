import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../donations/edit_donation_admin.dart';
import 'view_donations_admin.dart';

/// Staff screen: review & moderate donation records.
///
/// Features (logic unchanged):
///  • Live stream of `donations` collection (ordered by date desc)
///  • In-memory filters: store name, volunteer email, food type, date range
///  • Edit button to open EditDonationAdminPage
///  • Approve / Reject actions that update `status` in Firestore
class ViewDonationsAdminPage extends StatefulWidget {
  const ViewDonationsAdminPage({super.key});

  @override
  State<ViewDonationsAdminPage> createState() =>
      _ViewDonationsAdminPageState();
}

class _ViewDonationsAdminPageState extends State<ViewDonationsAdminPage> {
  // ─────────────────────────────────────────────
  // Filter state (store, volunteer, food, dates)
  // ─────────────────────────────────────────────
  String? _storeFilter;
  String? _volunteerFilter;
  String? _foodTypeFilter;
  DateTime? _fromDate;
  DateTime? _toDate;

  // ─────────────────────────────────────────────
  // Date pickers (logic unchanged)
  // ─────────────────────────────────────────────

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _fromDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _toDate ?? DateTime.now(),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  // ─────────────────────────────────────────────
  // Simple text-based filters (store / volunteer / food)
  // Logic is exactly the same, just comments added.
  // ─────────────────────────────────────────────

  Future<void> _setStoreFilter() async {
    final controller = TextEditingController(text: _storeFilter ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by store'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Store name contains...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() {
        _storeFilter = value.isEmpty ? null : value;
      });
    }
  }

  Future<void> _setVolunteerFilter() async {
    final controller = TextEditingController(text: _volunteerFilter ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by volunteer email'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Email contains...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() {
        _volunteerFilter = value.isEmpty ? null : value;
      });
    }
  }

  Future<void> _setFoodTypeFilter() async {
    final controller = TextEditingController(text: _foodTypeFilter ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by food type'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Food type contains...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    if (value != null) {
      setState(() {
        _foodTypeFilter = value.isEmpty ? null : value;
      });
    }
  }

  // ─────────────────────────────────────────────
  // Firestore status update (approve / reject)
  // ─────────────────────────────────────────────

  Future<void> _updateStatus(
      DocumentReference ref,
      String newStatus,
      ) async {
    try {
      await ref.update({
        'status': newStatus,
        if (newStatus == 'approved')
          'approvedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as $newStatus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  // ─────────────────────────────────────────────
  // UI
  // Only theming/layout is changed to match Delivery tracking:
  //  • Black AppBar with white title
  //  • Photo background with dark overlay
  //  • Large white filter "overview" card
  //  • White rounded donation cards
  // No Firestore/filter/approval logic has been touched.
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // Black app bar like DeliveryTrackingPage.
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Review donations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // The page body is a Stack so we can show a background image
      // with a semi-transparent dark overlay, then the content on top.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same style as delivery tracking).
          Image.asset(
            'assets/staff_bg.jpg', // change if your asset path is different
            fit: BoxFit.cover,
          ),
          // Dim overlay so text/cards stay readable.
          Container(color: Colors.black.withOpacity(0.55)),

          // Foreground content.
          SafeArea(
            child: Column(
              children: [
                // ────────────── Overview / Filters card ──────────────
                Card(
                  margin:
                  const EdgeInsets.fromLTRB(16, 12, 16, 8), // top spacing
                  elevation: 4,
                  color: Colors.white.withOpacity(0.96),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Review overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Filter, review, and approve donations in real time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Store filter button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _setStoreFilter,
                                icon: const Icon(Icons.store),
                                label: Text(
                                  _storeFilter == null ||
                                      _storeFilter!.isEmpty
                                      ? 'Filter by store'
                                      : 'Store: $_storeFilter',
                                ),
                                style: _filterButtonStyle(colorScheme),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Volunteer filter button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _setVolunteerFilter,
                                icon: const Icon(Icons.person_outline),
                                label: Text(
                                  _volunteerFilter == null ||
                                      _volunteerFilter!.isEmpty
                                      ? 'Filter by volunteer'
                                      : 'Volunteer: $_volunteerFilter',
                                ),
                                style: _filterButtonStyle(colorScheme),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Food type filter button
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _setFoodTypeFilter,
                                icon: const Icon(Icons.restaurant),
                                label: Text(
                                  _foodTypeFilter == null ||
                                      _foodTypeFilter!.isEmpty
                                      ? 'Filter by food type'
                                      : 'Food: $_foodTypeFilter',
                                ),
                                style: _filterButtonStyle(colorScheme),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Date range filter buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickFromDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _fromDate == null
                                      ? 'From date'
                                      : '${_fromDate!.year}-${_fromDate!.month.toString().padLeft(2, '0')}-${_fromDate!.day.toString().padLeft(2, '0')}',
                                ),
                                style: _filterButtonStyle(colorScheme),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickToDate,
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  _toDate == null
                                      ? 'To date'
                                      : '${_toDate!.year}-${_toDate!.month.toString().padLeft(2, '0')}-${_toDate!.day.toString().padLeft(2, '0')}',
                                ),
                                style: _filterButtonStyle(colorScheme),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 4),

                // Small "All donations" label to mirror Delivery tracking.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All donations',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // ────────────── Live donations list ──────────────
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('donations')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
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

                      var docs = snapshot.data?.docs ?? [];

                      // Apply in-memory filters to the streamed docs.
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final storeName =
                        (data['storeName'] ?? '') as String;
                        final volunteerEmail =
                        (data['volunteerEmail'] ?? '') as String;
                        final items =
                        (data['items'] ?? []) as List<dynamic>;
                        final ts = data['date'] as Timestamp?;
                        final date = ts?.toDate();

                        // Store filter
                        if (_storeFilter != null &&
                            _storeFilter!.isNotEmpty &&
                            !storeName
                                .toLowerCase()
                                .contains(_storeFilter!.toLowerCase())) {
                          return false;
                        }

                        // Volunteer filter
                        if (_volunteerFilter != null &&
                            _volunteerFilter!.isNotEmpty &&
                            !volunteerEmail
                                .toLowerCase()
                                .contains(_volunteerFilter!.toLowerCase())) {
                          return false;
                        }

                        // Food type filter (any item matches)
                        if (_foodTypeFilter != null &&
                            _foodTypeFilter!.isNotEmpty) {
                          final match = items.any((item) {
                            final m = item as Map<String, dynamic>;
                            final type = (m['foodType'] ?? '')
                                .toString()
                                .toLowerCase();
                            return type
                                .contains(_foodTypeFilter!.toLowerCase());
                          });
                          if (!match) return false;
                        }

                        // Date range filters
                        if (_fromDate != null && date != null) {
                          if (date.isBefore(
                              _fromDate!.subtract(const Duration(days: 1)))) {
                            return false;
                          }
                        }
                        if (_toDate != null && date != null) {
                          if (date
                              .isAfter(_toDate!.add(const Duration(days: 1)))) {
                            return false;
                          }
                        }

                        return true;
                      }).toList();

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No donations match these filters.',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.only(
                            left: 8, right: 8, bottom: 12, top: 4),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;

                          final storeName =
                          (data['storeName'] ?? '') as String;
                          final totalKg =
                          (data['totalKg'] ?? 0.0).toDouble();
                          final totalBoxes =
                          (data['totalBoxes'] ?? 0) as int;
                          final items =
                          (data['items'] ?? []) as List<dynamic>;
                          final ts = data['date'] as Timestamp?;
                          final date = ts?.toDate();
                          final status =
                          (data['status'] ?? 'pending') as String;
                          final notes = (data['notes'] ?? '') as String;

                          final dateLabel = date == null
                              ? ''
                              : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

                          // Build multiline food summary string.
                          final foodSummary = items.map((item) {
                            final m = item as Map<String, dynamic>;
                            final type =
                            (m['foodType'] ?? '').toString();
                            final boxes = (m['boxes'] ?? 0) as int;
                            final kg = (m['kg'] ?? 0.0).toDouble();
                            return '$type: ${kg.toStringAsFixed(1)} kg • $boxes boxes';
                          }).join('\n');

                          final isPending = status == 'pending';

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            color: Colors.white,
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row: store name + edit icon + status chip
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          storeName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit donation',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  EditDonationAdminPage(
                                                    donationRef: doc.reference,
                                                    initialData: data,
                                                  ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(
                                          Icons.edit,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Chip(
                                        label: Text(status),
                                        backgroundColor: status == 'approved'
                                            ? Colors.green
                                            .withOpacity(0.15)
                                            : status == 'rejected'
                                            ? Colors.red
                                            .withOpacity(0.15)
                                            : Colors.grey
                                            .withOpacity(0.15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),

                                  // Food summary
                                  Text(
                                    foodSummary.isEmpty
                                        ? 'Food: (no items?)'
                                        : 'Food:\n$foodSummary',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                  const SizedBox(height: 4),

                                  // Weight / boxes
                                  Text(
                                    'Weight: ${totalKg.toStringAsFixed(1)} kg • Boxes: $totalBoxes',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  const SizedBox(height: 2),

                                  // Date
                                  Text(
                                    'Date: $dateLabel',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),

                                  // Optional notes
                                  if (notes.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Notes: $notes',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ],

                                  const SizedBox(height: 8),

                                  // Action buttons row: Reject / Approve
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: isPending
                                            ? () => _updateStatus(
                                          doc.reference,
                                          'rejected',
                                        )
                                            : null,
                                        icon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        label: const Text('Reject'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: isPending
                                            ? () => _updateStatus(
                                          doc.reference,
                                          'approved',
                                        )
                                            : null,
                                        icon: const Icon(
                                          Icons.check,
                                          size: 18,
                                        ),
                                        label: const Text('Approve'),
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                          colorScheme.primary,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(20),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  // Reusable style for the rounded purple filter buttons
  // inside the white overview card.
  ButtonStyle _filterButtonStyle(ColorScheme colorScheme) {
    return OutlinedButton.styleFrom(
      side: BorderSide(color: colorScheme.primary),
      foregroundColor: colorScheme.primary,
      textStyle: const TextStyle(fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor: colorScheme.primary.withOpacity(0.03),
    );
  }
}

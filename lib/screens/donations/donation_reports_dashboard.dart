import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DonationReportsDashboardPage extends StatefulWidget {
  const DonationReportsDashboardPage({super.key});

  @override
  State<DonationReportsDashboardPage> createState() =>
      _DonationReportsDashboardPageState();
}

class _DonationReportsDashboardPageState
    extends State<DonationReportsDashboardPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _volunteerFilterController =
  TextEditingController();
  final TextEditingController _storeFilterController = TextEditingController();

  DateTime? _fromDate;
  DateTime? _toDate;

  bool _loading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  final List<QueryDocumentSnapshot> _docs = [];
  static const int _pageSize = 30;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _volunteerFilterController.dispose();
    _storeFilterController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Pagination logic (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> _loadInitial() async {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      Query query = _firestore
          .collection('donations')
          .orderBy('date', descending: true)
          .limit(_pageSize);

      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _docs.addAll(snapshot.docs);
        _lastDoc = snapshot.docs.last;
      }
      if (snapshot.docs.length < _pageSize) _hasMore = false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load donation data')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ─────────────────────────────────────────────
  // Date pickers (UNCHANGED)
  // ─────────────────────────────────────────────
  Future<void> _pickFromDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now,
    );
    if (picked != null) setState(() => _fromDate = picked);
  }

  Future<void> _pickToDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? now,
      firstDate: now.subtract(const Duration(days: 365 * 3)),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _toDate = picked);
  }

  void _clearDates() => setState(() {
    _fromDate = null;
    _toDate = null;
  });

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} "
        "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}";
  }

  // ─────────────────────────────────────────────
  // Apply filters (UNCHANGED)
  // ─────────────────────────────────────────────
  List<QueryDocumentSnapshot> _applyFilters() {
    final volFilter = _volunteerFilterController.text.trim().toLowerCase();
    final storeFilter = _storeFilterController.text.trim().toLowerCase();

    return _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final volunteer = (data['volunteerName'] as String? ?? '').toLowerCase();
      final store = (data['storeName'] as String? ?? '').toLowerCase();
      final ts = data['date'] as Timestamp?;

      if (volFilter.isNotEmpty && !volunteer.contains(volFilter)) return false;
      if (storeFilter.isNotEmpty && !store.contains(storeFilter)) return false;

      if (_fromDate != null || _toDate != null) {
        if (ts == null) return false;
        final d = ts.toDate();
        final date = DateTime(d.year, d.month, d.day);
        if (_fromDate != null && date.isBefore(_fromDate!)) return false;
        if (_toDate != null && date.isAfter(_toDate!)) return false;
      }
      return true;
    }).toList();
  }

  // ─────────────────────────────────────────────
  // UI – themed to match Manage schedules
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredDocs = _applyFilters();

    // All logic stays the same – just reused for display.
    double totalWeight = filteredDocs.fold(0, (sum, doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      return sum + ((data['weightKg'] as num?)?.toDouble() ?? 0);
    });

    return Scaffold(
      // Black app bar like the schedules screen
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Donation reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo like Manage schedules
          Image.asset(
            'assets/staff_bg.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay “black bar” effect
          Container(color: Colors.black.withOpacity(0.55)),

          // Foreground content
          SafeArea(
            child: Column(
              children: [
                // ───────────── Overview header card (white, floating) ─────────────
                Card(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  elevation: 8,
                  color: Colors.white.withOpacity(0.96), // same feel as schedules
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reports overview',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Monitor donations and totals in real-time.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Top row – store / volunteer filters
                        Row(
                          children: [
                            Expanded(
                              child: _buildFilterDropdown(
                                controller: _storeFilterController,
                                label: 'Filter by store',
                                icon: Icons.store_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildFilterDropdown(
                                controller: _volunteerFilterController,
                                label: 'Filter by volunteer',
                                icon: Icons.person_outline,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Date range + refresh (styled like chips/buttons)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickFromDate,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _fromDate == null
                                      ? 'From date'
                                      : "${_fromDate!.year}-${_fromDate!.month}-${_fromDate!.day}",
                                ),
                                style: _dateButtonStyle(colorScheme),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickToDate,
                                icon: const Icon(Icons.date_range),
                                label: Text(
                                  _toDate == null
                                      ? 'To date'
                                      : "${_toDate!.year}-${_toDate!.month}-${_toDate!.day}",
                                ),
                                style: _dateButtonStyle(colorScheme),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Reset filters & reload',
                              icon: const Icon(Icons.refresh),
                              onPressed: _loadInitial,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Records + total (simple text, like stats in header)
                        Text(
                          'Records: ${filteredDocs.length}  |  '
                              'Total: ${totalWeight.toStringAsFixed(1)} kg',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                // ───────────── Section label “All donations” ─────────────
                Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'All donations',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // ───────────── Donation cards on transparent background ─────────────
                Expanded(
                  child: filteredDocs.isEmpty
                      ? const Center(
                    child: Text(
                      'No donation records found.',
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data = filteredDocs[index].data()
                      as Map<String, dynamic>? ??
                          {};
                      final store =
                      (data['storeName'] ?? 'Unknown') as String;
                      final volunteer =
                      (data['volunteerName'] ?? '-') as String;
                      final food =
                      (data['foodType'] ?? 'Unknown') as String;
                      final weight =
                      ((data['weightKg'] ?? 0) as num).toDouble();
                      final ts = data['date'] as Timestamp?;
                      final dateText =
                      ts != null ? _formatDate(ts) : '-';

                      // Card style matches schedule list items:
                      // white, rounded, slight elevation on dark overlay.
                      return Card(
                        color: Colors.white,
                        elevation: 4,
                        margin:
                        const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Volunteer: $volunteer',
                                      style:
                                      const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      'Food: $food',
                                      style:
                                      const TextStyle(fontSize: 13),
                                    ),
                                    Text(
                                      'Date: $dateText',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${weight.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
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

  // ─────────────────────────────────────────────
  // Filter text fields – styled like soft pill controls on white card
  // ─────────────────────────────────────────────
  Widget _buildFilterDropdown({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey.shade700),
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade700),
        filled: true,
        fillColor: Colors.grey.shade200,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide.none,
        ),
        isDense: true,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  // ─────────────────────────────────────────────
  // Date button style – pill-shaped outline, matches filter look
  // ─────────────────────────────────────────────
  ButtonStyle _dateButtonStyle(ColorScheme colorScheme) {
    return OutlinedButton.styleFrom(
      side: BorderSide(color: colorScheme.primary),
      foregroundColor: colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      textStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

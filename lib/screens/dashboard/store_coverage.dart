import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Staff view: list of all stores, their assigned volunteers,
/// and scheduled pickup times, with filters + pagination.
class StoreCoveragePage extends StatefulWidget {
  const StoreCoveragePage({super.key});

  @override
  State<StoreCoveragePage> createState() => _StoreCoveragePageState();
}

class _StoreCoveragePageState extends State<StoreCoveragePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Filter by store name.
  final TextEditingController _storeFilterController = TextEditingController();

  // Filter by pickup date.
  DateTime? _selectedDate;

  // Paged data from Firestore.
  final List<QueryDocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDoc;

  static const int _pageSize = 25;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _storeFilterController.dispose();
    super.dispose();
  }

  /// Reset pagination and load the first page.
  Future<void> _loadInitial() async {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
    });
    await _loadMore();
  }

  /// Load the next page from Firestore.
  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;

    setState(() {
      _loading = true;
    });

    try {
      Query query = _firestore
          .collection('schedules')
          .orderBy('pickupDate');

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      query = query.limit(_pageSize);

      final snapshot = await query.get();

      if (!mounted) return;

      if (snapshot.docs.isNotEmpty) {
        setState(() {
          _docs.addAll(snapshot.docs);
          _lastDoc = snapshot.docs.last;
        });
      }

      if (snapshot.docs.length < _pageSize) {
        setState(() {
          _hasMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load coverage data'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Apply store-name + date filters client-side on the loaded page.
  List<QueryDocumentSnapshot> _applyFilters() {
    final filterText = _storeFilterController.text.trim().toLowerCase();
    final hasStoreFilter = filterText.isNotEmpty;
    final hasDateFilter = _selectedDate != null;

    return _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final storeName =
      (data['storeName'] as String? ?? '').toLowerCase();
      final ts = data['pickupDate'] as Timestamp?;

      if (hasStoreFilter && !storeName.contains(filterText)) {
        return false;
      }

      if (hasDateFilter && ts != null) {
        final d = ts.toDate();
        final dateOnly = DateTime(d.year, d.month, d.day);
        if (dateOnly != _selectedDate) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// Show date picker and set the date filter.
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 2);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  /// Clear the current date filter.
  void _clearDate() {
    setState(() {
      _selectedDate = null;
    });
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _formatSelectedDate() {
    if (_selectedDate == null) return '';
    final d = _selectedDate!;
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final filteredDocs = _applyFilters();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Store Coverage'),
      ),
      body: Column(
        children: [
          // Thin top loading bar while fetching.
          if (_loading && _docs.isEmpty) const LinearProgressIndicator(),

          // Filters section (matches existing dashboard style).
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _storeFilterController,
                  decoration: InputDecoration(
                    labelText: 'Filter by store name',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon:
                    _storeFilterController.text.isEmpty
                        ? null
                        : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _storeFilterController.clear();
                        setState(() {});
                      },
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _selectedDate == null
                              ? 'Filter by date'
                              : _formatSelectedDate(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDate != null)
                      TextButton(
                        onPressed: _clearDate,
                        child: const Text('Clear date'),
                      ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: _loadInitial,
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Data table.
          Expanded(
            child: _loading && _docs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredDocs.isEmpty
                ? const Center(
              child: Text(
                'No schedules found for current filters.',
              ),
            )
                : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Store')),
                    DataColumn(label: Text('Volunteer')),
                    DataColumn(label: Text('Assigned time')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: filteredDocs.map((doc) {
                    final data =
                        doc.data() as Map<String, dynamic>? ??
                            {};

                    final storeName =
                    (data['storeName'] as String? ?? '')
                        .trim();
                    final volunteerName =
                    (data['volunteerName'] as String? ?? '')
                        .trim();
                    final ts =
                    data['pickupDate'] as Timestamp?;
                    final startTime =
                    (data['startTime'] as String? ?? '')
                        .trim();
                    final endTime =
                    (data['endTime'] as String? ?? '')
                        .trim();
                    final timeWindow =
                    (data['timeWindow'] as String? ?? '')
                        .trim();
                    final status =
                    (data['status'] as String? ?? 'scheduled')
                        .trim();

                    final dateText =
                    ts == null ? '' : _formatDate(ts);

                    String assignedTime;
                    if (startTime.isNotEmpty &&
                        endTime.isNotEmpty &&
                        dateText.isNotEmpty) {
                      assignedTime =
                      '$dateText $startTime - $endTime';
                    } else if (timeWindow.isNotEmpty &&
                        dateText.isNotEmpty) {
                      assignedTime =
                      '$dateText $timeWindow';
                    } else {
                      assignedTime = dateText.isEmpty
                          ? '-'
                          : dateText;
                    }

                    final volunteerDisplay =
                    volunteerName.isEmpty
                        ? 'Unassigned'
                        : volunteerName;

                    final statusDisplay =
                    status == 'ready'
                        ? 'Ready'
                        : 'Scheduled';

                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            storeName.isEmpty
                                ? 'Unknown store'
                                : storeName,
                          ),
                        ),
                        DataCell(Text(volunteerDisplay)),
                        DataCell(Text(assignedTime)),
                        DataCell(Text(statusDisplay)),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),

          // Pagination controls ("Load more").
          if (_hasMore || _loading)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed:
                    _loading || !_hasMore ? null : _loadMore,
                    child: Text(
                      _hasMore ? 'Load more' : 'No more rows',
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

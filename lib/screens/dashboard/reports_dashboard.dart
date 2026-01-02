import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Donation Reports Dashboard — themed to match other app pages.
/// Shows filters, summary breakdown cards and an itemized list of donations.
class ReportsDashboardPage extends StatefulWidget {
  const ReportsDashboardPage({super.key});

  @override
  State<ReportsDashboardPage> createState() => _ReportsDashboardPageState();
}

class _ReportsDashboardPageState extends State<ReportsDashboardPage> {
  /// Shared Firestore instance used for all queries on this page.
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// In-memory text filters for volunteer name and store name.
  final TextEditingController _volunteerFilterController =
  TextEditingController();
  final TextEditingController _donorFilterController = TextEditingController();

  /// Optional date range filters.
  DateTime? _fromDate;
  DateTime? _toDate;

  /// Pagination state.
  bool _loading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;

  /// Raw donation documents loaded so far (unfiltered list).
  final List<QueryDocumentSnapshot> _docs = <QueryDocumentSnapshot>[];

  /// Cache of volunteerId → volunteer display name.
  final Map<String, String> _volunteerNames = {}; // volunteerId → name

  /// Number of documents to load per page from Firestore.
  static const int _pageSize = 50;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  @override
  void dispose() {
    _volunteerFilterController.dispose();
    _donorFilterController.dispose();
    super.dispose();
  }

  /// Reset pagination state and load the first page of results.
  Future<void> _loadInitial() async {
    setState(() {
      _docs.clear();
      _lastDoc = null;
      _hasMore = true;
      _volunteerNames.clear();
    });
    await _loadMore();
  }

  /// Load the next page of donation documents from Firestore.
  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);

    try {
      // Base query: donation documents ordered by descending date.
      Query query = _firestore
          .collection('donations')
          .orderBy('date', descending: true)
          .limit(_pageSize);

      // If we already have data, start after the last document we saw.
      if (_lastDoc != null) query = query.startAfterDocument(_lastDoc!);

      final snapshot = await query.get();
      final newDocs = snapshot.docs;

      // When fewer docs than page size are returned, we've reached the end.
      if (newDocs.length < _pageSize) _hasMore = false;
      if (newDocs.isNotEmpty) _lastDoc = newDocs.last;

      // Collect volunteer IDs from this batch so we can resolve names.
      final ids = <String>{};
      for (final doc in newDocs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final id = (data['volunteerId'] ?? data['volunteer_id']) as String?;
        if (id != null && id.isNotEmpty) ids.add(id);
      }

      // Fetch volunteer display names for any IDs we do not know yet.
      await _fetchVolunteerNames(ids);

      setState(() => _docs.addAll(newDocs));
    } catch (e) {
      debugPrint('Error loading donation reports: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load donations')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Look up volunteer documents for any missing volunteer IDs.
  /// Populates [_volunteerNames] as a local cache.
  Future<void> _fetchVolunteerNames(Set<String> ids) async {
    final missing =
    ids.where((id) => !_volunteerNames.containsKey(id)).toList();
    if (missing.isEmpty) return;

    for (final id in missing) {
      try {
        final doc = await _firestore.collection('volunteers').doc(id).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final name = (data['name'] ??
              data['fullName'] ??
              data['displayName'] ??
              data['username'])
              ?.toString();
          if (name != null && name.trim().isNotEmpty) {
            _volunteerNames[id] = name.trim();
          }
        }
      } catch (_) {
        // Ignore failures here; fall back to generic volunteer labels.
      }
    }
  }

  /// Resolve the volunteer display name for a donation document.
  /// Falls back to various fields and defaults when necessary.
  String _getVolunteerName(Map<String, dynamic> data) {
    final id = (data['volunteerId'] ?? data['volunteer_id']) as String?;
    if (id != null && _volunteerNames.containsKey(id)) {
      return _volunteerNames[id]!;
    }

    final name = (data['volunteerName'] ??
        data['volunteer_name'] ??
        data['volunteer'])
        ?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();

    if (id != null && id.isNotEmpty) return 'Volunteer';
    return 'Not recorded';
  }

  /// Resolve the store/donor name from multiple possible field names.
  String _getStoreName(Map<String, dynamic> data) {
    final name = (data['storeName'] ??
        data['store_name'] ??
        data['donorName'] ??
        data['donor_name'] ??
        data['store'])
        ?.toString();
    if (name != null && name.trim().isNotEmpty) return name.trim();
    return 'Unknown store';
  }

  /// Extract a comma-separated list of food types from the `items` array.
  String _getFoodName(Map<String, dynamic> data) {
    final items = data['items'];
    final List<String> foodTypes = [];
    if (items is List) {
      for (final i in items) {
        if (i is Map && i['foodType'] != null) {
          final ft = i['foodType'].toString().trim();
          if (ft.isNotEmpty && !foodTypes.contains(ft)) foodTypes.add(ft);
        }
      }
    }
    if (foodTypes.isNotEmpty) return foodTypes.join(', ');
    return '';
  }

  /// Compute the total weight for a donation in kilograms.
  /// Uses `totalKg` when present, otherwise sums item-level kg fields.
  double _getWeight(Map<String, dynamic> data) {
    final total = data['totalKg'] ?? data['total_kg'];
    if (total is num) return total.toDouble();
    if (total is String) return double.tryParse(total) ?? 0.0;

    double sum = 0;
    final items = data['items'];
    if (items is List) {
      for (final i in items) {
        if (i is Map && i['kg'] != null) {
          final kg = i['kg'];
          if (kg is num) sum += kg.toDouble();
          if (kg is String) sum += double.tryParse(kg) ?? 0.0;
        }
      }
    }
    return sum;
  }

  /// Apply all active filters (volunteer, store, date range) to the
  /// locally loaded donation documents.
  List<QueryDocumentSnapshot> _applyFilters() {
    final volunteerF = _volunteerFilterController.text.trim().toLowerCase();
    final donorF = _donorFilterController.text.trim().toLowerCase();

    return _docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final volunteerName = _getVolunteerName(data).toLowerCase();
      final storeName = _getStoreName(data).toLowerCase();

      final ts = data['date'] as Timestamp?;
      final date = ts?.toDate();

      // Text filters.
      if (volunteerF.isNotEmpty && !volunteerName.contains(volunteerF)) {
        return false;
      }
      if (donorF.isNotEmpty && !storeName.contains(donorF)) {
        return false;
      }

      // Date range: inclusive from / to.
      if (_fromDate != null &&
          date != null &&
          date.isBefore(DateTime(
              _fromDate!.year, _fromDate!.month, _fromDate!.day))) {
        return false;
      }
      if (_toDate != null &&
          date != null &&
          date.isAfter(DateTime(
              _toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59))) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Show a date picker and update either the "from" or "to" date.
  Future<void> _pickDate(bool from) async {
    final now = DateTime.now();
    final initial = from ? (_fromDate ?? now) : (_toDate ?? now);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (from) {
          _fromDate = picked;
        } else {
          _toDate = picked;
        }
      });
    }
  }

  /// Build a CSV string from the given docs and copy it to the clipboard.
  Future<void> _exportCsv(List<QueryDocumentSnapshot> docs) async {
    final buf = StringBuffer();
    buf.writeln('date,store,volunteer,food,weightKg');

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final ts = data['date'] as Timestamp?;
      final dateStr = ts != null ? ts.toDate().toIso8601String() : '';
      final store = _getStoreName(data).replaceAll('"', '""');
      final vol = _getVolunteerName(data).replaceAll('"', '""');
      final food = _getFoodName(data).replaceAll('"', '""');
      final weight = _getWeight(data);
      buf.writeln('"$dateStr","$store","$vol","$food",$weight');
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV copied to clipboard')),
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // UI Section (updated theme)
  // ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Apply all filters before building the UI.
    final filtered = _applyFilters();

    // Aggregate totals for summary stats and breakdown cards.
    double total = 0;
    final byStore = <String, _Agg>{};
    final byVol = <String, _Agg>{};

    for (final d in filtered) {
      final data = d.data() as Map<String, dynamic>? ?? {};
      final w = _getWeight(data);
      total += w;

      final s = _getStoreName(data);
      final v = _getVolunteerName(data);

      byStore.putIfAbsent(s, () => _Agg()).add(w);
      byVol.putIfAbsent(v, () => _Agg()).add(w);
    }

    final avg = filtered.isNotEmpty ? total / filtered.length : 0.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white), // makes back arrow white
        title: const Text(
          'Donation reports',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.black.withOpacity(0.7),
        elevation: 0,
        centerTitle: false,
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with dark overlay (matches other staff screens).
          Image.asset('assets/staff_bg.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),

          // Foreground content.
          Column(
            children: [
              _buildFiltersBar(filtered.length, total, avg, filtered),
              _buildBreakdown('By store', byStore),
              _buildBreakdown('By volunteer', byVol),
              const Divider(height: 1, color: Colors.white24),
              Expanded(child: _buildList(filtered)),
            ],
          ),
        ],
      ),
    );
  }

  /// Top card that includes text filters, date filters and action icons.
  Widget _buildFiltersBar(
      int count, double total, double avg, List<QueryDocumentSnapshot> docs) {
    return Card(
      color: Colors.white.withOpacity(0.92),
      margin: const EdgeInsets.fromLTRB(12, 90, 12, 8),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            // Volunteer + store text filters.
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volunteerFilterController,
                    decoration: InputDecoration(
                      labelText: 'Filter by volunteer',
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _donorFilterController,
                    decoration: InputDecoration(
                      labelText: 'Filter by store',
                      prefixIcon: const Icon(Icons.store_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date range + clear + refresh + CSV actions.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(true),
                    icon: const Icon(Icons.date_range, color: Colors.green),
                    label: Text(
                      _fromDate == null
                          ? 'From date'
                          : _fromDate!.toString().split(' ')[0],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(false),
                    icon: const Icon(Icons.date_range, color: Colors.green),
                    label: Text(
                      _toDate == null
                          ? 'To date'
                          : _toDate!.toString().split(' ')[0],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Clear dates',
                  onPressed: () {
                    setState(() {
                      _fromDate = null;
                      _toDate = null;
                    });
                  },
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadInitial,
                  icon: const Icon(Icons.refresh, color: Colors.green),
                ),
                IconButton(
                  tooltip: 'Copy CSV',
                  onPressed: docs.isEmpty ? null : () => _exportCsv(docs),
                  icon: const Icon(Icons.download, color: Colors.green),
                ),
              ],
            ),
            // Summary stats line (records + total kg + average).
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Records: $count • Total: ${total.toStringAsFixed(1)} kg • Avg: ${avg.toStringAsFixed(1)} kg/donation',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Summary card for aggregation by either store or volunteer.
  Widget _buildBreakdown(String title, Map<String, _Agg> map) {
    if (map.isEmpty) return const SizedBox.shrink();

    // Sort entries in descending order by total weight.
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.total.compareTo(a.value.total));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        color: Colors.white.withOpacity(0.9),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 6),
              for (final e in entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(e.key)),
                      Text(
                        '${e.value.count} × ${e.value.total.toStringAsFixed(1)} kg (avg ${e.value.average.toStringAsFixed(1)} kg)',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// List of individual donation entries with store, volunteer, food and weight.
  Widget _buildList(List<QueryDocumentSnapshot> docs) {
    if (_loading && docs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (docs.isEmpty) {
      return const Center(
        child: Text(
          'No donations found.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ListView.separated(
      itemCount: docs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      itemBuilder: (_, i) {
        final data = docs[i].data() as Map<String, dynamic>? ?? {};
        final store = _getStoreName(data);
        final volunteer = _getVolunteerName(data);
        final food = _getFoodName(data);
        final weight = _getWeight(data);
        final ts = data['date'] as Timestamp?;
        final dateStr = ts != null ? ts.toDate().toString().split('.')[0] : '';

        return Card(
          color: Colors.white.withOpacity(0.95),
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            title: Text(
              store,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Volunteer: $volunteer'),
                if (food.isNotEmpty) Text('Food: $food'),
                if (dateStr.isNotEmpty)
                  Text(
                    'Date: $dateStr',
                    style:
                    const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
              ],
            ),
            trailing: Text(
              '${weight.toStringAsFixed(1)} kg',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple aggregation helper: keeps a count and total weight,
/// and exposes a derived average value.
class _Agg {
  int count = 0;
  double total = 0;

  /// Add a new value into the aggregate.
  void add(double v) {
    count++;
    total += v;
  }

  /// Average value (total / count), or 0 when no items.
  double get average => count > 0 ? total / count : 0;
}

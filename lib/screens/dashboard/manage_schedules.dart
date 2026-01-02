import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Staff screen: create, list and delete pickup schedules.
///
/// Data model (Firestore `schedules` collection):
/// - storeId / storeName
/// - volunteerId / volunteerName (optional)
/// - pickupDate (Timestamp)
//  - timeWindow (string, e.g. "09:00 AM - 10:00 AM")
/// - status (scheduled / completed / cancelled)
/// - createdAt (server timestamp)
class ManageSchedulesPage extends StatefulWidget {
  const ManageSchedulesPage({super.key});

  @override
  State<ManageSchedulesPage> createState() => _ManageSchedulesPageState();
}

class _ManageSchedulesPageState extends State<ManageSchedulesPage> {
  // ─────────────────────────────────────────────
  // Form state for the "Add schedule" dialog
  // ─────────────────────────────────────────────
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String? _selectedStoreId;
  String? _selectedVolunteerId;

  // Store & volunteer options loaded from Firestore.
  // Each map has: { 'id': <docId>, 'name': <display name> }
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _volunteers = [];

  // Loading / saving flags.
  bool _loadingStores = true;
  bool _loadingVolunteers = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
    _loadVolunteers();
  }

  /// Fetch all stores from Firestore (for the dropdown).
  Future<void> _loadStores() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('stores').get();

      final stores = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'name': doc['storeName'] ?? 'Unnamed store',
      })
          .toList();

      setState(() {
        _stores = stores;
        _loadingStores = false;
      });
    } catch (e) {
      setState(() => _loadingStores = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stores: $e')),
      );
    }
  }

  /// Fetch all volunteers from Firestore (for optional assignment).
  Future<void> _loadVolunteers() async {
    try {
      final snapshot =
      await FirebaseFirestore.instance.collection('volunteers').get();

      final vols = snapshot.docs
          .map((doc) => {
        'id': doc.id,
        'name': doc['fullName'] ?? 'Unnamed volunteer',
      })
          .toList();

      setState(() {
        _volunteers = vols;
        _loadingVolunteers = false;
      });
    } catch (e) {
      setState(() => _loadingVolunteers = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load volunteers: $e')),
      );
    }
  }

  /// Live stream of all schedules so staff can see updates in real time.
  Stream<QuerySnapshot> _scheduleStream() {
    return FirebaseFirestore.instance
        .collection('schedules')
        .orderBy('pickupDate', descending: false)
        .snapshots();
  }

  /// Convert TimeOfDay to formatted string, e.g. "09:00 AM".
  /// (Logic unchanged – only used for display.)
  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Add a new schedule document to Firestore.
  /// (All field names and logic are untouched.)
  Future<void> _addSchedule() async {
    // Basic validation – store, date and time window are required.
    if (_selectedStoreId == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select store, date, and time window'),
        ),
      );
      return;
    }

    // Look up selected store object from cached list.
    final store =
    _stores.firstWhere((s) => s['id'] == _selectedStoreId, orElse: () => {});
    // Look up selected volunteer (optional).
    final volunteer = _selectedVolunteerId == null
        ? null
        : _volunteers.firstWhere(
          (v) => v['id'] == _selectedVolunteerId,
      orElse: () => {},
    );

    // Human-readable time window string.
    final formattedTimeWindow =
        '${_formatTime(_startTime!)} - ${_formatTime(_endTime!)}';

    setState(() => _saving = true);

    try {
      // Persist schedule in Firestore.
      await FirebaseFirestore.instance.collection('schedules').add({
        'storeId': _selectedStoreId,
        'storeName': store['name'] ?? '',
        'volunteerId': volunteer?['id'] ?? '',
        'volunteerName': volunteer?['name'] ?? '',
        'pickupDate': Timestamp.fromDate(_selectedDate!),
        'timeWindow': formattedTimeWindow,
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule added successfully')),
      );
      // Close the dialog after save.
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error adding schedule: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  /// Delete a schedule document by ID.
  Future<void> _deleteSchedule(String id) async {
    await FirebaseFirestore.instance.collection('schedules').doc(id).delete();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule deleted')),
    );
  }

  /// Open the "Add schedule" dialog with themed styling.
  /// Business logic is unchanged; this only tweaks the look.
  void _openAddDialog() {
    // Reset temporary form state each time dialog opens.
    _selectedStoreId = null;
    _selectedVolunteerId = null;
    _selectedDate = null;
    _startTime = null;
    _endTime = null;

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          title: const Text(
            'Add schedule',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          // StatefulBuilder lets the dialog manage its own internal state
          // without touching the main page's setState.
          content: StatefulBuilder(
            builder: (context, setInnerState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ───── Store dropdown ─────
                    _loadingStores
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : DropdownButtonFormField<String>(
                      value: _selectedStoreId,
                      decoration: InputDecoration(
                        labelText: 'Select store',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F2FA),
                      ),
                      items: _stores
                          .map(
                            (store) => DropdownMenuItem<String>(
                          value: store['id'],
                          child: Text(store['name'] as String),
                        ),
                      )
                          .toList(),
                      onChanged: (val) =>
                          setInnerState(() => _selectedStoreId = val),
                    ),
                    const SizedBox(height: 12),

                    // ───── Volunteer dropdown (optional) ─────
                    _loadingVolunteers
                        ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : DropdownButtonFormField<String>(
                      value: _selectedVolunteerId,
                      decoration: InputDecoration(
                        labelText: 'Assign volunteer (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF7F2FA),
                      ),
                      items: [
                        // Explicit option for "no volunteer".
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No volunteer assigned'),
                        ),
                        ..._volunteers.map(
                              (vol) => DropdownMenuItem<String>(
                            value: vol['id'] as String,
                            child: Text(vol['name'] as String),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setInnerState(() => _selectedVolunteerId = val),
                    ),
                    const SizedBox(height: 12),

                    // ───── Date picker row ─────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDate == null
                                ? 'No date selected'
                                : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 1),
                            );
                            if (picked != null) {
                              setInnerState(() => _selectedDate = picked);
                            }
                          },
                          icon: const Icon(
                            Icons.date_range,
                            color: Colors.green, // use green accent
                          ),
                          label: const Text('Pick date'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ───── Time range pickers row ─────
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _startTime ??
                                    const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (picked != null) {
                                setInnerState(() => _startTime = picked);
                              }
                            },
                            icon: const Icon(Icons.access_time),
                            label: Text(
                              _startTime == null
                                  ? 'Start time'
                                  : _formatTime(_startTime!),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: _endTime ??
                                    const TimeOfDay(hour: 10, minute: 0),
                              );
                              if (picked != null) {
                                setInnerState(() => _endTime = picked);
                              }
                            },
                            icon: const Icon(Icons.timelapse),
                            label: Text(
                              _endTime == null
                                  ? 'End time'
                                  : _formatTime(_endTime!),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _addSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, // green primary action
              ),
              child: _saving
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Build a small colored status chip ("Scheduled", "Completed", etc.).
  /// Only UI styling is changed; the status text mapping is the same.
  Widget _statusChip(String statusRaw) {
    final status = statusRaw.toLowerCase();
    Color color;
    String label;

    switch (status) {
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Cancelled';
        break;
      default:
        color = Colors.orange;
        label = 'Scheduled';
    }

    return Chip(
      backgroundColor: color.withOpacity(0.15),
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

  // ─────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Use green as the primary accent to match Delivery tracking.
    const primary = Colors.green;

    return Scaffold(
      backgroundColor: Colors.black, // dark base (like delivery tracking)
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manage schedules',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add schedule'),
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image like the Delivery tracking screen.
          // Make sure this asset exists, or change to your actual path.
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.black.withOpacity(0.55)),
          StreamBuilder<QuerySnapshot>(
            stream: _scheduleStream(),
            builder: (context, snapshot) {
              // Loading state.
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              // Error state.
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No schedules found.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              // Summary counts (pure UI logic, Firestore reads unchanged).
              int scheduledCount = 0;
              int completedCount = 0;
              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>? ?? {};
                final status =
                (data['status'] as String? ?? 'scheduled').toLowerCase();
                if (status == 'completed') {
                  completedCount++;
                } else {
                  scheduledCount++;
                }
              }

              return Padding(
                padding:
                const EdgeInsets.fromLTRB(16, 12, 16, 16), // inner padding
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ───── Overview card (matches Delivery tracking style) ─────
                    Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Schedule overview',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Monitor upcoming and completed pickups in real time.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _OverviewStatCard(
                                    title: 'Scheduled pickups',
                                    value: scheduledCount.toString(),
                                    icon: Icons.pending_actions_outlined,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _OverviewStatCard(
                                    title: 'Completed pickups',
                                    value: completedCount.toString(),
                                    icon: Icons.check_circle_outline,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'All schedules',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // ───── List of schedule cards ─────
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data =
                          docs[index].data() as Map<String, dynamic>;
                          final id = docs[index].id;

                          final storeName =
                              data['storeName'] ?? 'Unknown store';
                          final volunteer =
                              data['volunteerName'] ?? 'Unassigned';
                          final timeWindow = data['timeWindow'] ?? '';
                          final status = data['status'] ?? 'scheduled';

                          final ts = data['pickupDate'] as Timestamp?;
                          final date = ts?.toDate();
                          final dateLabel = date == null
                              ? 'Unknown date'
                              : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            color: Colors.white,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '$storeName — $dateLabel',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (timeWindow.isNotEmpty)
                                      Text(
                                        'Time: $timeWindow',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    Text(
                                      'Volunteer: $volunteer',
                                      style:
                                      const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 4),
                                    _statusChip(status),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteSchedule(id),
                                ),
                              ),
                            ),
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

/// Small pill-style overview card used in the header (like Delivery tracking).
class _OverviewStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _OverviewStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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

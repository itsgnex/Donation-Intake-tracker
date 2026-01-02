import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// StoreUnavailableDaysPage
///
/// Store partners can mark specific calendar days as **unavailable** so staff
/// don’t schedule pickups on those dates.
///
/// Data model:
/// - For the logged-in store document in `stores/{storeId}`
/// - Field `unavailableDates`: List<Timestamp> (each is a date, time stripped)
class StoreUnavailableDaysPage extends StatefulWidget {
  const StoreUnavailableDaysPage({super.key});

  @override
  State<StoreUnavailableDaysPage> createState() =>
      _StoreUnavailableDaysPageState();
}

class _StoreUnavailableDaysPageState extends State<StoreUnavailableDaysPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Days the store has marked as unavailable (date-only).
  Set<DateTime> _selectedDays = {};

  bool _loading = true; // true while we load from Firestore
  bool _saving = false; // true while we write back to Firestore

  /// Month that the calendar is currently showing (always day = 1).
  DateTime _focusedMonth =
  DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Helper: strip off time, keep only year-month-day.
  DateTime _strip(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _loadUnavailable();
  }

  /// Load the store's unavailable dates from Firestore.
  Future<void> _loadUnavailable() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in as a store.')),
      );
      return;
    }

    try {
      final doc = await _firestore.collection('stores').doc(uid).get();
      final data = doc.data() ?? {};

      final list = data['unavailableDates'] as List<dynamic>? ?? [];
      final set = <DateTime>{};

      for (final item in list) {
        if (item is Timestamp) {
          final d = item.toDate();
          set.add(_strip(d));
        }
      }

      setState(() {
        _selectedDays = set;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load unavailable days.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Save the currently selected unavailable dates back to Firestore.
  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in as a store.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final timestamps = _selectedDays
          .map((d) => Timestamp.fromDate(_strip(d)))
          .toList();

      await _firestore.collection('stores').doc(uid).update({
        'unavailableDates': timestamps,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unavailable days updated.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save unavailable days.'),
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

  /// Move calendar one month backward.
  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month - 1,
        1,
      );
    });
  }

  /// Move calendar one month forward.
  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + 1,
        1,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate month layout (number of days, first weekday, etc.)
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final startWeekday = firstDay.weekday; // 1 = Mon ... 7 = Sun

    final tiles = <Widget>[];

    // Add empty boxes before day 1 so calendar lines up with weekday header.
    for (int i = 1; i < startWeekday; i++) {
      tiles.add(const SizedBox.shrink());
    }

    // Add each day of the month as a tappable box.
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final selected = _selectedDays.contains(_strip(date));

      tiles.add(
        GestureDetector(
          onTap: () {
            setState(() {
              final d = _strip(date);
              if (_selectedDays.contains(d)) {
                _selectedDays.remove(d);
              } else {
                _selectedDays.add(d);
              }
            });
          },
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              // Red for unavailable (selected), white card for normal days.
              color: selected
                  ? Colors.redAccent
                  : Colors.white.withOpacity(0.96),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? Colors.redAccent
                    : Colors.grey.shade400,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ]
                  : [],
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight:
                selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,

        // 👇 makes back arrow + icons white (to match other store screens)
        iconTheme: const IconThemeData(color: Colors.white),

        title: const Text(
          'Unavailable days',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same as other store pages)
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for readability
          Container(color: Colors.black.withOpacity(0.55)),

          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else
            Column(
              children: [
                const SizedBox(height: 12),

                // ==== MONTH HEADER CARD ====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.97),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.20),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: _prevMonth,
                            ),
                            Text(
                              '${_focusedMonth.year}-${_focusedMonth.month.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: _nextMonth,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: const [
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Mon',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Tue',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Wed',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Thu',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Fri',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Sat',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Sun',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ==== CALENDAR GRID CARD ====
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.97),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: GridView.count(
                        crossAxisCount: 7,
                        children: tiles,
                      ),
                    ),
                  ),
                ),

                // ==== SAVE BUTTON ====
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 3,
                      ),
                      child: _saving
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Save unavailable days',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

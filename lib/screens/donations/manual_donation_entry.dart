import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Staff-only manual donation data entry form.
/// Matches dark theme (same as schedules/reports/register pages).
/// Only UI changes made for consistent look — NO logic changes.
class ManualDonationEntryPage extends StatefulWidget {
  const ManualDonationEntryPage({super.key});

  @override
  State<ManualDonationEntryPage> createState() => _ManualDonationEntryPageState();
}

class _ManualDonationEntryPageState extends State<ManualDonationEntryPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final List<_StoreOption> _stores = <_StoreOption>[];
  _StoreOption? _selectedStore;
  bool _loadingStores = false;

  final TextEditingController _volunteerNameController = TextEditingController();
  final TextEditingController _volunteerEmailController = TextEditingController();
  final TextEditingController _boxesController = TextEditingController();
  final TextEditingController _kgController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  DateTime? _selectedDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _volunteerNameController.dispose();
    _volunteerEmailController.dispose();
    _boxesController.dispose();
    _kgController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Load stores from Firestore
  // ─────────────────────────────────────────────
  Future<void> _loadStores() async {
    setState(() => _loadingStores = true);

    try {
      final query = await FirebaseFirestore.instance.collection('stores').orderBy('storeName').get();
      _stores.clear();

      for (final doc in query.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final name = (data['storeName'] as String? ?? 'Store').trim();
        final locationRaw = (data['location'] ?? data['city'] ?? data['address'] ?? '') as String?;
        final location = (locationRaw ?? '').trim();

        _stores.add(_StoreOption(
          id: doc.id,
          name: name.isEmpty ? 'Store' : name,
          location: location,
        ));
      }

      if (_stores.isNotEmpty && _selectedStore == null) {
        _selectedStore = _stores.first;
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load stores for selection.')),
      );
    } finally {
      if (mounted) setState(() => _loadingStores = false);
    }
  }

  // ─────────────────────────────────────────────
  // Date picker logic
  // ─────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ─────────────────────────────────────────────
  // Submit donation record to Firestore
  // ─────────────────────────────────────────────
  Future<void> _submit() async {
    if (_saving) return;

    if (_stores.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No stores available. Please add stores first.')),
      );
      return;
    }

    if (_selectedStore == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store.')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the donation date.')),
      );
      return;
    }

    final store = _selectedStore!;
    final volunteerName = _volunteerNameController.text.trim();
    final volunteerEmail = _volunteerEmailController.text.trim();
    final notes = _notesController.text.trim();
    final boxes = int.tryParse(_boxesController.text.trim()) ?? 0;
    final kg = double.tryParse(_kgController.text.trim().replaceAll(',', '.')) ?? 0.0;

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'date': Timestamp.fromDate(_selectedDate!),
        'storeId': store.id,
        'storeName': store.name,
        'storeLocation': store.location,
        'volunteerName': volunteerName,
        'volunteerEmail': volunteerEmail,
        'totalBoxes': boxes,
        'totalKg': kg,
        'notes': notes,
        'status': 'completed',
        'createdManually': true,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('donations').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation entry saved successfully.')),
      );

      // Reset form (keep selected store)
      setState(() => _selectedDate = null);
      _volunteerNameController.clear();
      _volunteerEmailController.clear();
      _boxesController.clear();
      _kgController.clear();
      _notesController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save donation entry. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _dateLabel() {
    if (_selectedDate == null) return 'Select date';
    final d = _selectedDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // ─────────────────────────────────────────────
  // Main UI (matches dark theme)
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bool showStoreLoading = _loadingStores && _stores.isEmpty;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manual donation entry',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with dark overlay
          Image.asset('assets/staff_bg.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),

          // Main content (floating white card)
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 8,
                color: Colors.white.withOpacity(0.96),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Add missing donation data',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use this form to manually enter donations that were not captured in the system. These entries will appear in your reports.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),

                        if (showStoreLoading) const LinearProgressIndicator(),
                        if (!showStoreLoading && _stores.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'No stores found. Please add store records first.',
                              style: TextStyle(color: Colors.red, fontSize: 13),
                            ),
                          ),

                        // ───────────── Store Dropdown ─────────────
                        DropdownButtonFormField<_StoreOption>(
                          value: _selectedStore,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Store',
                            border: OutlineInputBorder(),
                          ),
                          items: _stores
                              .map((store) => DropdownMenuItem<_StoreOption>(
                            value: store,
                            child: Text(store.location.isEmpty
                                ? store.name
                                : '${store.name} • ${store.location}'),
                          ))
                              .toList(),
                          onChanged: _loadingStores
                              ? null
                              : (value) => setState(() => _selectedStore = value),
                          validator: (value) => value == null ? 'Please select a store.' : null,
                        ),
                        const SizedBox(height: 16),

                        // ───────────── Date Picker Button ─────────────
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(_dateLabel()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ───────────── Volunteer Name ─────────────
                        TextFormField(
                          controller: _volunteerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Volunteer name (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ───────────── Volunteer Email ─────────────
                        TextFormField(
                          controller: _volunteerEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Volunteer email (optional)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return null;
                            final emailRegex = RegExp(r'^[^@]+@[^@]+\\.[^@]+$');
                            if (!emailRegex.hasMatch(text)) {
                              return 'Enter a valid email or leave blank.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // ───────────── Total boxes & kg fields ─────────────
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _boxesController,
                                decoration: const InputDecoration(
                                  labelText: 'Total boxes',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return 'Enter boxes (0 if none).';
                                  final parsed = int.tryParse(text);
                                  if (parsed == null || parsed < 0) return 'Enter a non-negative number.';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _kgController,
                                decoration: const InputDecoration(
                                  labelText: 'Total kg',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                validator: (value) {
                                  final text = value?.trim() ?? '';
                                  if (text.isEmpty) return 'Enter kg (0 if none).';
                                  final parsed = double.tryParse(text.replaceAll(',', '.'));
                                  if (parsed == null || parsed < 0) return 'Enter a non-negative number.';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // ───────────── Notes Field ─────────────
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ───────────── Save Button (Green, Matches Theme) ─────────────
                        SizedBox(
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: (_loadingStores || _stores.isEmpty || _saving) ? null : _submit,
                            icon: _saving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving…' : 'Save entry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Store option model (unchanged)
// ─────────────────────────────────────────────
class _StoreOption {
  final String id;
  final String name;
  final String location;

  _StoreOption({required this.id, required this.name, required this.location});
}
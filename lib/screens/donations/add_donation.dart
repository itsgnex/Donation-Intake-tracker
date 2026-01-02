import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';

/// Volunteer screen to log new donations.
/// - Lets the volunteer pick a store and a date
/// - Add one or more donation items (food type + boxes + kg)
/// - Optionally add notes
/// - Saves to `donations` collection with volunteer + store info
class AddDonationPage extends StatefulWidget {
  const AddDonationPage({super.key});

  @override
  State<AddDonationPage> createState() => _AddDonationPageState();
}

class _AddDonationPageState extends State<AddDonationPage> {
  /// Used if you want to add validation later to the entire form.
  final _formKey = GlobalKey<FormState>();

  /// Notes text field controller.
  final TextEditingController _notesController = TextEditingController();

  /// Store options loaded from Firestore.
  List<Map<String, dynamic>> _stores = [];

  /// Currently selected store ID.
  String? _selectedStoreId;

  /// Loading flags for the store dropdown & submit button.
  bool _loadingStores = true;
  bool _saving = false;

  /// Donation date (defaults to "today").
  DateTime _selectedDate = DateTime.now();

  /// Food type options for each line item.
  final List<String> _foodTypes = const [
    'Dairy',
    'Vegetables',
    'Fruits',
    'Meat',
    'Grains',
    'Canned',
    'Bakery',
    'Other',
  ];

  /// The list of line items currently on the form.
  final List<_DonationItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadStores(); // load store choices
    _addItem(); // start with a single blank item row
  }

  /// Load all stores from Firestore so the volunteer can pick one.
  Future<void> _loadStores() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('stores')
          .orderBy('storeName')
          .get();

      final stores = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': (data['storeName'] ?? 'Store') as String,
        };
      }).toList();

      setState(() {
        _stores = stores;
        _loadingStores = false;
      });
    } catch (e) {
      setState(() => _loadingStores = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load stores: $e')),
      );
    }
  }

  /// Add another donation line item.
  void _addItem() {
    setState(() {
      _items.add(_DonationItem());
    });
  }

  /// Remove an item row by index.
  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  /// Show a date picker for the donation date.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(_selectedDate.year - 1),
      lastDate: DateTime(_selectedDate.year + 1),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Validate and submit the donation to Firestore.
  /// **No logic changed here, just comments.**
  Future<void> _submit() async {
    if (_selectedStoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a store.')),
      );
      return;
    }

    // Logged-in volunteer info (from AuthService).
    final user = AuthService.currentUser;
    final String? volunteerId = user?.uid;
    final String? volunteerEmail = user?.email;
    final String volunteerName = user?.displayName ?? '';

    // Collect all item rows into a simple list.
    final List<Map<String, dynamic>> itemsData = [];
    var totalBoxes = 0;
    var totalKg = 0.0;

    for (final item in _items) {
      final type = item.foodType;
      final boxesText = item.boxesController.text.trim();
      final kgText = item.kgController.text.trim();

      final boxes = int.tryParse(boxesText) ?? 0;
      final kg = double.tryParse(kgText) ?? 0.0;

      if (type == null || type.isEmpty || (boxes <= 0 && kg <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Each item needs a food type and boxes and/or kg greater than 0.',
            ),
          ),
        );
        return;
      }

      itemsData.add({
        'foodType': type,
        'boxes': boxes,
        'kg': kg,
      });

      totalBoxes += boxes;
      totalKg += kg;
    }

    if (itemsData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one donation item.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final store = _stores.firstWhere((s) => s['id'] == _selectedStoreId);

      final data = <String, dynamic>{
        'storeId': _selectedStoreId,
        'storeName': store['name'],
        // Link donation to volunteer account
        'volunteerId': volunteerId,
        'volunteerEmail': volunteerEmail,
        'volunteerName': volunteerName,
        'items': itemsData,
        'totalBoxes': totalBoxes,
        'totalKg': totalKg,
        'notes': _notesController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending', // so staff can approve/decline
      };

      await FirebaseFirestore.instance.collection('donations').add(data);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation logged')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save donation: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      // match other dark/overlay screens
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Log donations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // BACKGROUND IMAGE (same as volunteer login/dashboard)
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // DARK OVERLAY
          Container(color: Colors.black.withOpacity(0.55)),

          // MAIN CONTENT
          if (_loadingStores)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (_stores.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No stores available.\nPlease contact staff.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            )
          else
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Container(
                  // white “card” floating in the middle
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ─── Store dropdown ───────────────────────
                        DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: 'Store',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                          ),
                          value: _selectedStoreId,
                          items: _stores
                              .map(
                                (store) => DropdownMenuItem<String>(
                              value: store['id'] as String,
                              child: Text(store['name'] as String),
                            ),
                          )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStoreId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // ─── Date selector (pill style) ─────────
                        Center(
                          child: OutlinedButton.icon(
                            onPressed: _pickDate,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              shape: const StadiumBorder(),
                              side: BorderSide(
                                color: color.primary.withOpacity(0.4),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            icon: Icon(
                              Icons.date_range,
                              color: color.primary,
                            ),
                            label: Text(
                              '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: color.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Items header ───────────────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Items',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: color.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ─── Dynamic list of item cards ────────
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return Card(
                              margin:
                              const EdgeInsets.symmetric(vertical: 6),
                              color: const Color(0xFFF9F6FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        // Food type dropdown
                                        Expanded(
                                          child: DropdownButtonFormField<
                                              String>(
                                            decoration: InputDecoration(
                                              labelText: 'Food type',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                            value: item.foodType,
                                            items: _foodTypes
                                                .map(
                                                  (type) =>
                                                  DropdownMenuItem<String>(
                                                    value: type,
                                                    child: Text(type),
                                                  ),
                                            )
                                                .toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                item.foodType = value;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Remove row icon (if more than one)
                                        if (_items.length > 1)
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removeItem(index),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Boxes + Kg fields side-by-side
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller:
                                            item.boxesController,
                                            keyboardType:
                                            TextInputType.number,
                                            decoration: InputDecoration(
                                              labelText: 'Boxes',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: TextField(
                                            controller: item.kgController,
                                            keyboardType:
                                            const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            decoration: InputDecoration(
                                              labelText: 'Kg',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                BorderRadius.circular(14),
                                              ),
                                              filled: true,
                                              fillColor: Colors.white,
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
                        ),
                        const SizedBox(height: 10),

                        // ─── Add another item link ─────────────
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _addItem,
                            icon: Icon(
                              Icons.add,
                              color: color.primary,
                            ),
                            label: Text(
                              'Add another item',
                              style: TextStyle(color: color.primary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ─── Notes field ───────────────────────
                        TextField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: 'Additional notes (optional)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),

                        // ─── Submit button ─────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
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
                              'Submit',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
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

/// Model for a single line item in the donation form.
/// Keeps its own controllers so the page can have multiple rows.
class _DonationItem {
  String? foodType;
  final TextEditingController boxesController;
  final TextEditingController kgController;

  _DonationItem()
      : boxesController = TextEditingController(),
        kgController = TextEditingController();
}

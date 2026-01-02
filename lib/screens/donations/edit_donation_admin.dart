import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Admin screen to edit an existing donation document.
///
/// The page receives a [donationRef] pointing at the document in Firestore and
/// [initialData] containing the current values, then lets staff update items,
/// totals, notes and date.
class EditDonationAdminPage extends StatefulWidget {
  /// Reference to the donation document in Firestore.
  final DocumentReference donationRef;

  /// Initial snapshot data for the donation (used to pre-fill the form).
  final Map<String, dynamic> initialData;

  const EditDonationAdminPage({
    super.key,
    required this.donationRef,
    required this.initialData,
  });

  @override
  State<EditDonationAdminPage> createState() => _EditDonationAdminPageState();
}

class _EditDonationAdminPageState extends State<EditDonationAdminPage> {
  /// Form key for validating/saving the donation edit form.
  final _formKey = GlobalKey<FormState>();

  /// Notes input controller.
  late TextEditingController _notesController;

  /// Selected date for the donation (pickup/drop-off date).
  late DateTime _selectedDate;

  /// Available food type options for dropdowns.
  final List<String> _foodTypes = const [
    'Dairy',
    'Farm Products',
    'Vegetables',
    'Meat',
    'Fruits',
    'Bakery',
    'Dry Goods',
    'Other',
  ];

  /// In-memory list of editable donation items.
  late List<_DonationItem> _items;

  /// Whether a save operation is in progress.
  bool _saving = false;

  @override
  void initState() {
    super.initState();

    // Pre-fill notes from the incoming donation data.
    final data = widget.initialData;
    _notesController =
        TextEditingController(text: (data['notes'] ?? '').toString());

    // Pre-fill date from donation timestamp, fallback to now.
    final ts = data['date'] as Timestamp?;
    _selectedDate = ts?.toDate() ?? DateTime.now();

    // Build editable item list from existing `items` or create a single blank.
    final itemsData = (data['items'] ?? []) as List<dynamic>;
    _items = itemsData.isEmpty
        ? [ _DonationItem() ]
        : itemsData.map((raw) {
      final m = raw as Map<String, dynamic>;
      return _DonationItem(
        foodType: (m['foodType'] ?? '').toString(),
        boxes: (m['boxes'] ?? 0) as int,
        kg: (m['kg'] ?? 0.0).toDouble(),
      );
    }).toList();
  }

  @override
  void dispose() {
    // Dispose top-level controller and all inner controllers in items.
    _notesController.dispose();
    for (final item in _items) {
      item.boxesController.dispose();
      item.kgController.dispose();
    }
    super.dispose();
  }

  /// Convenience getter that sums all item boxes from the controllers.
  int get _totalBoxes {
    var sum = 0;
    for (final item in _items) {
      final n = int.tryParse(item.boxesController.text.trim());
      if (n != null && n > 0) sum += n;
    }
    return sum;
  }

  /// Convenience getter that sums all item kg from the controllers.
  double get _totalKg {
    var sum = 0.0;
    for (final item in _items) {
      final n = double.tryParse(item.kgController.text.trim());
      if (n != null && n > 0) sum += n;
    }
    return sum;
  }

  /// Add a new blank donation item row.
  void _addItem() {
    setState(() {
      _items.add(_DonationItem());
    });
  }

  /// Remove donation item at [index] (while keeping at least one row).
  void _removeItem(int index) {
    if (_items.length == 1) return;
    setState(() {
      _items[index].boxesController.dispose();
      _items[index].kgController.dispose();
      _items.removeAt(index);
    });
  }

  /// Open a date picker and update [_selectedDate] if a date is chosen.
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: _selectedDate,
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Validate and save all changes back to Firestore.
  Future<void> _save() async {
    final List<Map<String, dynamic>> itemsData = [];
    var totalBoxes = 0;
    var totalKg = 0.0;

    // Validate each item and accumulate totals.
    for (final item in _items) {
      final type = item.foodType;
      final boxesText = item.boxesController.text.trim();
      final kgText = item.kgController.text.trim();

      final boxes = int.tryParse(boxesText) ?? 0;
      final kg = double.tryParse(kgText) ?? 0.0;

      // Require a valid food type and at least one positive quantity.
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
      // Persist updated items, totals, notes and date to the document.
      await widget.donationRef.update({
        'items': itemsData,
        'totalBoxes': totalBoxes,
        'totalKg': totalKg,
        'notes': _notesController.text.trim(),
        'date': Timestamp.fromDate(_selectedDate),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donation updated')),
      );
      Navigator.of(context).pop(); // back to review list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update donation: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    // Store name is read only, obtained from initial data.
    final storeName = (widget.initialData['storeName'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit donation'),
      ),
      body: Container(
        // Background gradient using theme colors for a subtle admin feel.
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primary.withValues(alpha: 0.05),
              color.secondary.withValues(alpha: 0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Store (read-only, just shows which donor this belongs to).
                          TextFormField(
                            enabled: false,
                            initialValue: storeName,
                            decoration: const InputDecoration(
                              labelText: 'Store',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Section header for donation items.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Donation items',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Dynamic list of editable donation item rows.
                          ...List.generate(_items.length, (index) {
                            final item = _items[index];
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == _items.length - 1 ? 0 : 12,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.dividerColor
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Food type dropdown for this item.
                                    DropdownButtonFormField<String>(
                                      decoration: const InputDecoration(
                                        labelText: 'Food type',
                                        border: OutlineInputBorder(),
                                      ),
                                      value: item.foodType?.isEmpty == true
                                          ? null
                                          : item.foodType,
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
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        // Boxes input
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                            item.boxesController,
                                            keyboardType:
                                            TextInputType.number,
                                            decoration:
                                            const InputDecoration(
                                              labelText: 'Boxes',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Kg input
                                        Expanded(
                                          child: TextFormField(
                                            controller: item.kgController,
                                            keyboardType:
                                            const TextInputType
                                                .numberWithOptions(
                                              decimal: true,
                                            ),
                                            decoration:
                                            const InputDecoration(
                                              labelText: 'Kg',
                                              border: OutlineInputBorder(),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        // Delete button for this item row
                                        IconButton(
                                          onPressed: _items.length == 1
                                              ? null
                                              : () => _removeItem(index),
                                          icon: const Icon(
                                              Icons.delete_outline),
                                          constraints:
                                          const BoxConstraints(),
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const SizedBox(height: 8),

                          // Button to add another donation item row.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Add another item'),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Date section label.
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Pickup / drop-off date',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Date selector button.
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _pickDate,
                                  icon: const Icon(Icons.calendar_today),
                                  label: Text(
                                    '${_selectedDate.day.toString().padLeft(2, '0')}/'
                                        '${_selectedDate.month.toString().padLeft(2, '0')}/'
                                        '${_selectedDate.year}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Optional notes field.
                          TextFormField(
                            controller: _notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'Notes (optional)',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Chip showing computed totals for quick reference.
                          Align(
                            alignment: Alignment.centerRight,
                            child: Chip(
                              avatar:
                              const Icon(Icons.inventory_2_outlined),
                              label: Text(
                                'Total: $_totalBoxes boxes • ${_totalKg.toStringAsFixed(1)} kg',
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Primary save button; disabled while saving.
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text('Save changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Model for a single editable donation item row.
///
/// Wraps controllers for boxes/kg so they can be directly bound to text fields.
class _DonationItem {
  /// Current selected food type (may be null/empty until chosen).
  String? foodType;

  /// Text controllers bound to the numeric inputs.
  final TextEditingController boxesController;
  final TextEditingController kgController;

  _DonationItem({
    String? foodType,
    int boxes = 0,
    double kg = 0.0,
  })  : foodType = foodType,
        boxesController =
        TextEditingController(text: boxes > 0 ? '$boxes' : ''),
        kgController =
        TextEditingController(text: kg > 0 ? '$kg' : '');
}

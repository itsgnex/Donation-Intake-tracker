import 'package:flutter/material.dart';

/// A page where stores can manually add donation records.
/// Includes category selection, weight, boxes count, and notes.
/// Displays a success snackbar upon submission and then pops the page.
class StoreAddDonation extends StatefulWidget {
  const StoreAddDonation({super.key});

  @override
  State<StoreAddDonation> createState() => _StoreAddDonationState();
}

class _StoreAddDonationState extends State<StoreAddDonation> {
  /// List of donation categories.
  final categoryList = ['Produce', 'Dairy', 'Bakery', 'Grocery', 'Other'];

  /// Currently selected category.
  String selectedCategory = 'Produce';

  /// Controllers for form fields.
  final weightController = TextEditingController();
  final boxesController = TextEditingController();
  final notesController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Donation (Store)'),
        backgroundColor: Colors.greenAccent.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Category selection dropdown
            const Text('Donation Category', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              items: categoryList
                  .map((category) => DropdownMenuItem(
                  value: category, child: Text(category)))
                  .toList(),
              onChanged: (value) => setState(() => selectedCategory = value!),
            ),
            const SizedBox(height: 20),

            /// Weight input field
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            /// Boxes count input field
            TextField(
              controller: boxesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Total Boxes',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),

            /// Notes input field
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Additional Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 30),

            /// Submit button
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent.shade700,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Donation recorded successfully!')),
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  'Submit Donation',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

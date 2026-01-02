import 'package:flutter/material.dart';

/// Simple view for a store to see a list of its most recent donations.
///
/// Currently uses a hard-coded list of recent donations as sample data.
/// Each donation shows category, weight and number of boxes.
class StoreViewDonation extends StatelessWidget {
  const StoreViewDonation({super.key});

  @override
  Widget build(BuildContext context) {
    // Hard-coded sample donations list for display.
    // In a real app this could come from Firestore or an API.
    final recentDonations = [
      {'category': 'Produce', 'weight': '25 kg', 'boxes': '5'},
      {'category': 'Dairy', 'weight': '15 kg', 'boxes': '3'},
      {'category': 'Bakery', 'weight': '10 kg', 'boxes': '2'},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Recent Donations'),
        backgroundColor: Colors.orangeAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        // Scrollable list of donation cards.
        child: ListView.builder(
          itemCount: recentDonations.length,
          itemBuilder: (context, index) {
            final donation = recentDonations[index];
            return Card(
              color: Colors.orangeAccent.withOpacity(0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: ListTile(
                leading: const Icon(Icons.inventory, color: Colors.white),
                title: Text(
                  donation['category']!,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                subtitle: Text(
                  'Weight: ${donation['weight']}\nBoxes: ${donation['boxes']}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

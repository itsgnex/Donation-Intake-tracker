import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Staff screen:
/// Review *pending* store registration requests and approve / reject them.
///
/// Uses two collections:
/// - `approval_requests` (type = 'store', status = 'pending')
/// - `stores` (status field is updated to 'approved' or 'rejected')
class ManageStoresPage extends StatelessWidget {
  const ManageStoresPage({super.key});

  /// Approve or reject a single store registration request.
  ///
  /// LOGIC UNCHANGED:
  /// - Reads `userId` and `name` from the approval request doc.
  /// - Updates the corresponding document in `stores`.
  /// - Updates the approval request document in `approval_requests`.
  Future<void> _handleDecision(
      BuildContext context,
      DocumentSnapshot doc,
      bool approve,
      ) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final String userId = (data['userId'] ?? '').toString();
    final String name = (data['name'] ?? '').toString();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid request: missing userId.')),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;

    try {
      // Update store status (approved / rejected).
      await firestore.collection('stores').doc(userId).set({
        'status': approve ? 'approved' : 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update the approval request status.
      await firestore.collection('approval_requests').doc(doc.id).set({
        'status': approve ? 'approved' : 'rejected',
        'decisionAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
          Text(approve ? 'Approved store: $name' : 'Rejected store: $name'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update store status.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Query: all *pending* approval requests of type 'store'.
    // (Logic unchanged, only UI below is different.)
    final Query storeRequestsQuery = FirebaseFirestore.instance
        .collection('approval_requests')
        .where('type', isEqualTo: 'store')
        .where('status', isEqualTo: 'pending');

    const primary = Colors.green; // green accent to match other staff pages

    return Scaffold(
      // Dark base like the Delivery tracking / staff pages.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manage Store Registrations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image (same style as other staff screens).
          // Make sure this asset exists or change the path to one that does.
          Image.asset(
            'assets/staff_bg.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for readability.
          Container(color: Colors.black.withOpacity(0.55)),
          // Main content driven by Firestore stream.
          StreamBuilder<QuerySnapshot>(
            stream: storeRequestsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading store requests.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              final docs = snapshot.data?.docs ?? [];

              // Empty state – message on top of dark background.
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending store registrations.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Small overview card at the top.
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
                              'Store registrations',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review new store sign-ups and approve or reject.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _OverviewPill(
                                    icon: Icons.store_mall_directory_outlined,
                                    color: primary,
                                    title: 'Pending stores',
                                    value: docs.length.toString(),
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
                      'Pending requests',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // List of pending store registration cards.
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};

                          final name =
                          (data['name'] ?? 'Unknown Store').toString();
                          final email = (data['email'] ?? '').toString();
                          final createdAt = data['createdAt'] as Timestamp?;
                          final createdText = createdAt != null
                              ? createdAt
                              .toDate()
                              .toLocal()
                              .toString()
                              .split('.')
                              .first
                              : 'Unknown time';

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
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (email.isNotEmpty) Text(email),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Requested: $createdText',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    // Small "Pending" chip to match other status chips.
                                    Chip(
                                      label: const Text(
                                        'Pending',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor:
                                      Colors.orange.withOpacity(0.12),
                                      labelStyle: const TextStyle(
                                        color: Colors.orange,
                                      ),
                                      materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ],
                                ),
                                // Approve / Reject actions – exact same logic,
                                // only wrapped in rounded icon containers.
                                trailing: Wrap(
                                  spacing: 6,
                                  children: [
                                    // Reject button.
                                    InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () =>
                                          _handleDecision(context, doc, false),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color:
                                          Colors.red.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                    // Approve button.
                                    InkWell(
                                      borderRadius: BorderRadius.circular(24),
                                      onTap: () =>
                                          _handleDecision(context, doc, true),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color:
                                          primary.withOpacity(0.10),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.check,
                                          size: 20,
                                          color: primary,
                                        ),
                                      ),
                                    ),
                                  ],
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

/// Small pill used in the overview card to show a number + icon.
class _OverviewPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _OverviewPill({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
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

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Staff screen:
/// Review *pending* volunteer registration requests and approve / reject them.
///
/// Uses two collections:
/// - `approval_requests` (type = 'volunteer', status = 'pending')
/// - `volunteers` (status field is updated to 'approved' or 'rejected')
class ManageVolunteersPage extends StatelessWidget {
  const ManageVolunteersPage({super.key});

  /// Approve or reject a single volunteer request.
  ///
  /// LOGIC UNCHANGED:
  /// - Reads `userId` and `name` from the approval request doc.
  /// - Updates the corresponding document in `volunteers`.
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
      // Update volunteer status (approved / rejected).
      await firestore.collection('volunteers').doc(userId).set({
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
          content: Text(
            approve
                ? 'Approved volunteer: $name'
                : 'Rejected volunteer: $name',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update volunteer status.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Query: all *pending* approval requests of type 'volunteer'.
    // (Same logic as before, just wrapped in new UI.)
    final Query volunteerRequestsQuery = FirebaseFirestore.instance
        .collection('approval_requests')
        .where('type', isEqualTo: 'volunteer')
        .where('status', isEqualTo: 'pending');

    const primary = Colors.green; // green accent like other staff screens

    return Scaffold(
      // Dark base to match staff / delivery tracking screens.
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Manage Volunteer Approvals',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo (same style as other staff pages).
          // Ensure this asset exists in your project.
          Image.asset(
            'assets/staff_bg.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay for contrast.
          Container(color: Colors.black.withOpacity(0.55)),
          // Stream-driven content.
          StreamBuilder<QuerySnapshot>(
            stream: volunteerRequestsQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading volunteer requests.',
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

              // Empty state – simple white message in the middle.
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No pending volunteer registrations.',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overview card at the top.
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
                              'Volunteer approvals',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Review new volunteer sign-ups and approve or reject.',
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
                                    icon: Icons.volunteer_activism_outlined,
                                    color: primary,
                                    title: 'Pending volunteers',
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

                    // List of pending volunteer cards.
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data =
                              doc.data() as Map<String, dynamic>? ?? {};

                          final name =
                          (data['name'] ?? 'Volunteer').toString();
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
                                    // "Pending" chip to match other status chips.
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
                                // Approve / Reject actions – same logic,
                                // wrapped in circular colored backgrounds.
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

/// Shared overview pill (icon + title + value) used in the header card.
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

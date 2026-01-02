import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Store view: see details of volunteers assigned to this store.
///
/// - Looks at `schedules` where storeId == current store uid
/// - Collects all volunteerIds that are assigned
/// - For each volunteerId, loads the volunteer document from `volunteers`
/// - Shows name, email, phone, and upcoming pickup dates for this store
class StoreVolunteerDetailsPage extends StatelessWidget {
  const StoreVolunteerDetailsPage({super.key});

  /// Stream of all schedules for this store.
  Stream<QuerySnapshot> _storeSchedulesStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }

    return FirebaseFirestore.instance
        .collection('schedules')
        .where('storeId', isEqualTo: uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,

        // 👇 This makes the back arrow (and any other app bar icons) WHITE
        iconTheme: const IconThemeData(color: Colors.white),

        title: const Text(
          'Volunteer details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay so cards are readable
          Container(color: Colors.black.withOpacity(0.55)),

          StreamBuilder<QuerySnapshot>(
            stream: _storeSchedulesStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading volunteers',
                    style: TextStyle(
                      color: Colors.redAccent.shade100,
                      fontSize: 14,
                    ),
                  ),
                );
              }

              final scheduleDocs =
                  snapshot.data?.docs.cast<QueryDocumentSnapshot>() ?? [];

              if (scheduleDocs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No volunteers assigned yet.\nOnce staff assign volunteers to your pickups, they will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              // Collect all non-empty volunteerIds from schedules,
              // and keep a list of pickup dates per volunteer.
              final Map<String, List<DateTime>> datesByVolunteerId = {};
              for (final doc in scheduleDocs) {
                final data =
                    doc.data() as Map<String, dynamic>? ?? <String, dynamic>{};
                final String volunteerId =
                (data['volunteerId'] as String? ?? '').trim();
                if (volunteerId.isEmpty) continue;

                final ts = data['pickupDate'] as Timestamp?;
                final dt = ts?.toDate();
                if (dt == null) continue;

                datesByVolunteerId.putIfAbsent(volunteerId, () => []);
                datesByVolunteerId[volunteerId]!.add(dt);
              }

              if (datesByVolunteerId.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'No volunteers are currently assigned to your pickups.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              }

              final volunteerIds = datesByVolunteerId.keys.toList();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assigned volunteers',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'These volunteers are assigned to upcoming or recent pickups at your store.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Expanded(
                      child: ListView.builder(
                        itemCount: volunteerIds.length,
                        itemBuilder: (context, index) {
                          final volunteerId = volunteerIds[index];
                          final dates = datesByVolunteerId[volunteerId] ?? [];
                          return _VolunteerCard(
                            volunteerId: volunteerId,
                            pickupDates: dates,
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

/// A single volunteer info card (name, contact, pickup dates).
class _VolunteerCard extends StatelessWidget {
  final String volunteerId;
  final List<DateTime> pickupDates;

  const _VolunteerCard({
    required this.volunteerId,
    required this.pickupDates,
  });

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('volunteers')
          .doc(volunteerId)
          .get(),
      builder: (context, snapshot) {
        // While loading volunteer document.
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading volunteer...', style: TextStyle(fontSize: 13)),
              ],
            ),
          );
        }

        // If no document, show minimal card.
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                CircleAvatar(child: Icon(Icons.person)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Volunteer info not available',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          );
        }

        final data =
            snapshot.data!.data() as Map<String, dynamic>? ??
                <String, dynamic>{};

        // Try multiple field names for the volunteer's name:
        // fullName → name → displayName → 'Volunteer'
        final String name = (() {
          final dynamic f1 = data['fullName'];
          final dynamic f2 = data['name'];
          final dynamic f3 = data['displayName'];

          String? chosen;
          if (f1 is String && f1.trim().isNotEmpty) {
            chosen = f1;
          } else if (f2 is String && f2.trim().isNotEmpty) {
            chosen = f2;
          } else if (f3 is String && f3.trim().isNotEmpty) {
            chosen = f3;
          }

          final String nonNull = chosen ?? 'Volunteer';
          return nonNull.trim();
        })();

        final email = (data['email'] as String? ?? '').trim();
        final phone =
        (data['phone'] as String? ??
            data['phoneNumber'] as String? ??
            '')
            .trim();
        final photoUrl =
        (data['photoUrl'] as String? ??
            data['profileImageUrl'] as String? ??
            '')
            .trim();

        // Sort pickup dates ascending.
        pickupDates.sort((a, b) => a.compareTo(b));

        // Show only a few upcoming dates for readability.
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final upcoming = pickupDates
            .where((d) => !DateTime(d.year, d.month, d.day).isBefore(today))
            .toList();

        final List<DateTime> datesToShow =
        upcoming.isNotEmpty ? upcoming : pickupDates;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.94),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar (initial or profile image)
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.grey.shade200,
                backgroundImage:
                photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                child: photoUrl.isEmpty
                    ? Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                )
                    : null,
              ),
              const SizedBox(width: 12),
              // Main info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.grey.shade900,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (phone.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    if (email.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              email,
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (phone.isEmpty && email.isEmpty)
                      Text(
                        'Contact details not available.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Pickup dates:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (datesToShow.isEmpty)
                      Text(
                        'No pickup dates recorded.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: datesToShow
                            .take(5)
                            .map(
                              (d) => Chip(
                            label: Text(
                              _formatDate(d),
                              style: const TextStyle(fontSize: 11),
                            ),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

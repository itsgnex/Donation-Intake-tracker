import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Screen for staff/admin to manage staff invite emails.
/// Updated UI to match the dark theme style of other pages (e.g. donation reports, register, schedules).
/// No logic changes — only UI styling and layout improvements with comments for clarity.
class StaffInvitesPage extends StatefulWidget {
  const StaffInvitesPage({super.key});

  @override
  State<StaffInvitesPage> createState() => _StaffInvitesPageState();
}

class _StaffInvitesPageState extends State<StaffInvitesPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Add new invite to staffInvites collection.
  Future<void> _addInvite() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final auth = FirebaseAuth.instance;
      final currentUser = auth.currentUser;

      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final emailKey = email.toLowerCase();

      await firestore.collection('staffInvites').doc(emailKey).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByUid': currentUser?.uid,
        'createdByEmail': currentUser?.email,
      });

      _nameController.clear();
      _emailController.clear();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Staff invite added')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add invite: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Delete an invite document.
  Future<void> _deleteInvite(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('staffInvites').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite removed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to remove invite')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Staff invites', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ───────────── Background image and dark overlay ─────────────
          Image.asset('assets/staff_bg.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.55)),

          // ───────────── Main Content ─────────────
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Card(
                  elevation: 8,
                  color: Colors.white.withOpacity(0.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Add a staff invite',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                          const SizedBox(height: 12),

                          // Full Name field
                          TextFormField(
                            controller: _nameController,
                            decoration: InputDecoration(
                              labelText: 'Full name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Enter a name' : null,
                          ),
                          const SizedBox(height: 12),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) return 'Enter an email';
                              final v = value.trim();
                              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Add Staff Invite Button (Green to match theme)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saving ? null : _addInvite,
                              icon: _saving
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Icon(Icons.person_add_alt_1),
                              label: Text(_saving ? 'Saving...' : 'Add staff invite'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ───────────── List of existing invites ─────────────
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('staffInvites')
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      );
                    }

                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Failed to load invites', style: TextStyle(color: Colors.white)),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('No staff invites yet', style: TextStyle(color: Colors.white70)),
                      );
                    }

                    // List of staff invites (cards)
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>? ?? {};
                        final name = (data['name'] as String? ?? '').trim();
                        final email = (data['email'] as String? ?? '').trim();
                        final createdAt = data['createdAt'] as Timestamp?;
                        final createdByEmail = (data['createdByEmail'] as String? ?? '').trim();

                        String subtitle = email;
                        if (createdAt != null) {
                          final d = createdAt.toDate();
                          subtitle += '\nInvited: ${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
                        }
                        if (createdByEmail.isNotEmpty) {
                          subtitle += '\nBy: $createdByEmail';
                        }

                        // ───────────── Individual Staff Card ─────────────
                        return Card(
                          color: Colors.white.withOpacity(0.9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.person_outline, color: Colors.white),
                            ),
                            title: Text(name.isEmpty ? '(No name)' : name,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(subtitle),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () => _deleteInvite(doc.id),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
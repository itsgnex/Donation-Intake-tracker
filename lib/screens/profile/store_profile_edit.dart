import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// StoreProfileEditPage
/// ---------------------------------------------------------------------------
/// Store-side screen where a store partner can update:
///   • Store name
///   • Address
///   • Phone number
///   • Contact email
///
/// Data is loaded from the `stores/{storeUid}` document, where `storeUid` is
/// the Firebase Auth uid of the currently logged-in store account.
/// ---------------------------------------------------------------------------
class StoreProfileEditPage extends StatefulWidget {
  const StoreProfileEditPage({super.key});

  @override
  State<StoreProfileEditPage> createState() => _StoreProfileEditPageState();
}

class _StoreProfileEditPageState extends State<StoreProfileEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers for each field in the form.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _loading = true; // true while we’re fetching the current data
  bool _saving = false; // true while we’re sending an update to Firestore

  @override
  void initState() {
    super.initState();
    _loadStoreProfile();
  }

  /// Fetch the store profile from Firestore and populate the text fields.
  Future<void> _loadStoreProfile() async {
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
      final doc =
      await FirebaseFirestore.instance.collection('stores').doc(uid).get();

      final data = doc.data() ?? {};

      _nameController.text = (data['storeName'] as String? ?? '').trim();
      _addressController.text = (data['address'] as String? ?? '').trim();
      _phoneController.text = (data['phone'] as String? ?? '').trim();
      _emailController.text = (data['email'] as String? ?? '').trim();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load store info.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Validate the form and push updated values back to Firestore.
  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not logged in as a store.')),
      );
      return;
    }

    // Don’t try to save if the form is invalid.
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('stores').doc(uid).update({
        'storeName': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Store information updated.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save store info.'),
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

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Match other store screens (dark background under the image).
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Store Details',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background photo, same as other store pages.
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay so the white card is readable.
          Container(color: Colors.black.withOpacity(0.55)),

          if (_loading)
          // While loading from Firestore.
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
          // Centered white card with the form inside.
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(22),
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
                        const Text(
                          'Update store information',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Store name -------------------------------------------------
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Store name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Store name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Store address ----------------------------------------------
                        TextFormField(
                          controller: _addressController,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Store address',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Address is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Phone number -----------------------------------------------
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Phone number is required';
                            }
                            if (text.length < 8) {
                              return 'Phone number looks too short';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Contact email ---------------------------------------------
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Contact email',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) {
                              return 'Email is required';
                            }
                            if (!text.contains('@') || !text.contains('.')) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Save button (green, rounded, matches app theme) ----------
                        SizedBox(
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _saving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              elevation: 0,
                            ),
                            child: _saving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                                : const Text(
                              'Save changes',
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

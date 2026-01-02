import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class VolunteerProfilePage extends StatefulWidget {
  const VolunteerProfilePage({super.key});

  @override
  State<VolunteerProfilePage> createState() => _VolunteerProfilePageState();
}

class _VolunteerProfilePageState extends State<VolunteerProfilePage> {
  /// Form key for validating the profile fields.
  final _formKey = GlobalKey<FormState>();

  /// Controllers for the editable fields.
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  /// Email is shown but not editable.
  String? _email;

  /// Profile photo URL stored in Firestore / Storage.
  String? _photoUrl;

  /// UI state flags.
  bool _loadingProfile = true;
  bool _savingProfile = false;
  bool _uploadingPhoto = false;

  /// Convenience getter for the current Firebase user.
  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Load the volunteer profile from Firestore and prefill the form.
  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() => _loadingProfile = false);
      return;
    }

    _email = user.email;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        _fullNameController.text =
            (data['fullName'] as String? ?? '').trim();
        _phoneController.text =
            (data['phoneNumber'] as String? ?? '').trim();
        _locationController.text =
            (data['location'] as String? ?? '').trim();
        _photoUrl = (data['photoUrl'] as String?)?.trim();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
    }
  }

  /// Save profile fields back to Firestore.
  /// (Functionality unchanged – just UI styling around it.)
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _user;
    if (user == null) return;

    setState(() => _savingProfile = true);

    try {
      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(user.uid)
          .set(<String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'location': _locationController.text.trim(),
        'email': _email ?? user.email ?? '',
        'photoUrl': _photoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _savingProfile = false);
      }
    }
  }

  /// Pick a photo from the gallery and upload it to Firebase Storage.
  /// Then save the download URL on the volunteer document.
  Future<void> _pickAndUploadPhoto() async {
    final user = _user;
    if (user == null) return;

    final picker = ImagePicker();

    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (picked == null) return; // user cancelled

      setState(() => _uploadingPhoto = true);

      final file = File(picked.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('volunteer_profile_photos')
          .child('${user.uid}.jpg');

      await storageRef.putFile(file);
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('volunteers')
          .doc(user.uid)
          .set({'photoUrl': downloadUrl}, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update photo: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = Colors.green; // 💚 main accent for this page

    // While loading, show spinner over the same background style.
    if (_loadingProfile) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'My Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/bg_login.jpg',
              fit: BoxFit.cover,
            ),
            Container(color: Colors.black.withOpacity(0.55)),
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);

    // First letter used for avatar when no photo is set.
    final initial = (_fullNameController.text.isNotEmpty
        ? _fullNameController.text[0]
        : '?')
        .toUpperCase();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Same background as other volunteer screens
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay
          Container(color: Colors.black.withOpacity(0.55)),

          // Foreground content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── Avatar + camera button ─────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor:
                        Colors.white.withOpacity(0.96),
                        backgroundImage: _photoUrl != null &&
                            _photoUrl!.isNotEmpty
                            ? NetworkImage(_photoUrl!)
                            : null,
                        child: _photoUrl == null || _photoUrl!.isEmpty
                            ? Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: accent, // green initial
                          ),
                        )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _uploadingPhoto
                              ? null
                              : _pickAndUploadPhoto,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accent, // green chip
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: _uploadingPhoto
                                ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                                : const Icon(
                              Icons.camera_alt_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Card with profile form ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.97),
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
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'Volunteer Profile',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            'Set up your contact and location so staff can assign nearby stores',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Full name field
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            prefixIconColor: accent,
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide:
                              const BorderSide(color: accent),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Email (read-only)
                        TextFormField(
                          enabled: false,
                          initialValue: _email ?? '',
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon:
                            const Icon(Icons.email_outlined),
                            prefixIconColor: accent,
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide:
                              const BorderSide(color: accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Phone number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone number',
                            prefixIcon:
                            const Icon(Icons.phone_outlined),
                            prefixIconColor: accent,
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide:
                              const BorderSide(color: accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText:
                            'Location (for example: suburb or city)',
                            prefixIcon: const Icon(
                                Icons.location_on_outlined),
                            prefixIconColor: accent,
                            filled: true,
                            fillColor: const Color(0xFFF7F2FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide:
                              const BorderSide(color: accent),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Save button
                        SizedBox(
                          height: 48,
                          child: FilledButton(
                            onPressed:
                            _savingProfile ? null : _saveProfile,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: _savingProfile
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                                : const Text(
                              'Save profile',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
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

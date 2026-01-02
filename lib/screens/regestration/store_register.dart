import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Registration page for new store accounts.
///
/// - Creates a Firebase Auth user with email/password.
/// - Saves the store profile in the `stores` collection in Firestore.
/// - Navigates to the `storeDashboard` route on success.
class StoreRegisterPage extends StatefulWidget {
  const StoreRegisterPage({super.key});

  @override
  State<StoreRegisterPage> createState() => _StoreRegisterPageState();
}

class _StoreRegisterPageState extends State<StoreRegisterPage> {
  /// Form key to validate the entire registration form.
  final _formKey = GlobalKey<FormState>();

  /// Controllers for each form field.
  final _storeNameController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  /// Toggles for password visibility.
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  /// Whether a registration request is currently in progress.
  bool _loading = false;

  @override
  void dispose() {
    // Dispose all controllers to free resources.
    _storeNameController.dispose();
    _contactNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validate the form, create the auth user, and write the store document.
  Future<void> _register() async {
    // Ensure all validators pass first.
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // Simple local check for matching password fields.
    if (password != confirm) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _loading = true);

    try {
      // 1. Create auth user in Firebase Authentication.
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;

      // 2. Store corresponding profile document in Firestore (stores collection).
      await FirebaseFirestore.instance.collection('stores').doc(uid).set({
        'storeName': _storeNameController.text.trim(),
        'contactName': _contactNameController.text.trim(),
        'email': email,
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      });

      if (!mounted) return;

      // 3. Navigate to the store dashboard, clearing the navigation stack.
      Navigator.pushNamedAndRemoveUntil(
        context,
        'storeDashboard',
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      // Handle well-known Firebase auth errors with user-friendly messages.
      String msg = 'Registration failed.';
      if (e.code == 'email-already-in-use') {
        msg = 'Email already in use.';
      } else if (e.code == 'weak-password') {
        msg = 'Weak password.';
      }
      _showError(msg);
    } catch (_) {
      // Generic fallback error.
      _showError('Something went wrong.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Display an error dialog with a single OK button.
  void _showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background same as store login (branded store background).
          Image.asset('assets/store_bg.jpg', fit: BoxFit.cover),
          // Dark overlay to improve contrast with the foreground card.
          Container(color: Colors.black.withOpacity(0.4)),

          // Back arrow at top-left.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Foreground centered registration card.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title text.
                      const Text(
                        'Store registration',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Store name.
                      _inputField(
                        controller: _storeNameController,
                        label: 'Store name',
                        icon: Icons.storefront_outlined,
                      ),
                      const SizedBox(height: 12),

                      // Contact name.
                      _inputField(
                        controller: _contactNameController,
                        label: 'Contact name',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),

                      // Email address.
                      _inputField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 12),

                      // Phone number.
                      _inputField(
                        controller: _phoneController,
                        label: 'Phone',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),

                      // Address (multi-line).
                      _inputField(
                        controller: _addressController,
                        label: 'Address',
                        icon: Icons.location_on_outlined,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // Password field.
                      _passwordField(
                        controller: _passwordController,
                        label: 'Password',
                        obscure: _obscurePassword,
                        toggle: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Confirm password field.
                      _passwordField(
                        controller: _confirmPasswordController,
                        label: 'Confirm password',
                        obscure: _obscureConfirm,
                        toggle: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Submit / create account button.
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                              : const Text('Create store account'),
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

  /// Generic input field builder for most text inputs.
  Widget _inputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Require non-empty input for all fields using this helper.
      validator: (v) =>
      v == null || v.trim().isEmpty ? 'Required field' : null,
    );
  }

  /// Password input field builder with show/hide toggle.
  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback toggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
          ),
          onPressed: toggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // Basic password length validation for both password fields.
      validator: (v) =>
      v == null || v.length < 6 ? 'At least 6 characters' : null,
    );
  }
}

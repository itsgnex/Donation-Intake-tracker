import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Screen for volunteers to request a password reset email.
///
/// The user enters their email, and if valid, a reset email is sent via
/// FirebaseAuth. On success, a snackbar is shown and the page pops.
class VolunteerForgotPasswordPage extends StatefulWidget {
  const VolunteerForgotPasswordPage({super.key});

  @override
  State<VolunteerForgotPasswordPage> createState() =>
      _VolunteerForgotPasswordPageState();
}

class _VolunteerForgotPasswordPageState
    extends State<VolunteerForgotPasswordPage> {
  /// Controller for the volunteer email text field.
  final TextEditingController _emailController = TextEditingController();

  /// Whether a reset request is currently being sent (disables the button).
  bool _sending = false;

  /// Validate the email and send a password reset request via FirebaseAuth.
  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    // Simple validation before sending to Firebase.
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      // Trigger Firebase password reset email.
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
      // Go back to the previous screen after success.
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // Handle Firebase-specific errors gracefully.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to send reset email.'),
        ),
      );
    } catch (_) {
      // Fallback for any other exceptions.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to send reset email.'),
        ),
      );
    } finally {
      // Always reset loading state if still mounted.
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // Dispose controller to avoid memory leaks.
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Standard app bar for navigation and title.
      appBar: AppBar(
        title: const Text('Reset password'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image.
          Image.asset(
            'assets/bg_login.jpg',
            fit: BoxFit.cover,
          ),
          // Dark overlay to increase foreground contrast.
          Container(color: Colors.black.withOpacity(0.55)),
          // Centered dialog-style card with the reset form.
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title text.
                    const Text(
                      'Forgot password',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Short instruction description.
                    const Text(
                      'Enter your volunteer email and we will send a reset link.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    // Email input field.
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Volunteer email',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Submit / send reset button.
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: _sending ? null : _sendReset,
                        child: _sending
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : const Text('Send reset email'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

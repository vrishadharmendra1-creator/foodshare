import 'package:flutter/material.dart';
import 'auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'donor';
  bool _isLoading = false;
  String? _errorMessage;

  // Accepts things like "+1 555-123-4567", "5551234567", "(555) 123 4567".
  // Keeps validation forgiving about formatting but still catches empty /
  // obviously-not-a-phone-number input before it hits Firestore.
  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s\-\(\)]{7,15}$');

  String? _validatePhone() {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return 'Please enter a phone number.';
    if (!_phonePattern.hasMatch(phone)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  Future<void> _handleSignUp() async {
    final phoneError = _validatePhone();
    if (phoneError != null) {
      setState(() => _errorMessage = phoneError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        role: _selectedRole,
        phoneNumber: _phoneController.text.trim(),
      );
    } catch (e) {
      setState(() => _errorMessage = AuthService.friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignUp() async {
    // Google doesn't hand us a phone number, so we still require one
    // here -- the role + phone picked on this page travel along with
    // the Google sign-in and get saved onto the new user doc.
    final phoneError = _validatePhone();
    if (phoneError != null) {
      setState(() => _errorMessage = phoneError);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle(
        defaultRole: _selectedRole,
        phoneNumber: _phoneController.text.trim(),
      );
    } catch (e) {
      setState(() => _errorMessage = AuthService.friendlyAuthError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F7),
      appBar: AppBar(
        title: const Text(
          'Create Account',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF222222),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 15),

              // Logo
              Container(
                width: 90,
                height: 90,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  "assets/images/logo.png",
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 20),

              const Text(
                'Join FoodShare',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Create an account and help make a difference.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF777777),
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 28),

              // Sign Up Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4CAF50),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Create a password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4CAF50),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'e.g. +1 555 123 4567',
                        prefixIcon: const Icon(Icons.phone_outlined),
                        helperText:
                            'Shared with the donor/receiver you\'re matched '
                            'with, so pickups are easy to coordinate.',
                        helperMaxLines: 2,
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFF4CAF50),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    const Text(
                      'I am a:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF333333),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Donor
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedRole == 'donor'
                            ? const Color(0xFFEAF6EA)
                            : const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedRole == 'donor'
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: const Text(
                          'Donor',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'I want to share surplus food',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: 'donor',
                        groupValue: _selectedRole,
                        activeColor: const Color(0xFF4CAF50),
                        onChanged: (value) =>
                            setState(() => _selectedRole = value!),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Receiver
                    Container(
                      decoration: BoxDecoration(
                        color: _selectedRole == 'receiver'
                            ? const Color(0xFFEAF6EA)
                            : const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _selectedRole == 'receiver'
                              ? const Color(0xFF4CAF50)
                              : Colors.transparent,
                        ),
                      ),
                      child: RadioListTile<String>(
                        title: const Text(
                          'Receiver',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: const Text(
                          'I need or distribute food',
                          style: TextStyle(fontSize: 12),
                        ),
                        value: 'receiver',
                        groupValue: _selectedRole,
                        activeColor: const Color(0xFF4CAF50),
                        onChanged: (value) =>
                            setState(() => _selectedRole = value!),
                      ),
                    ),

                    const SizedBox(height: 22),

                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4CAF50),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: _handleSignUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade300)),
                      ],
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _handleGoogleSignUp,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Image.asset(
                          'assets/images/google_logo.png',
                          height: 20,
                        ),
                        label: const Text(
                          'Sign up with Google',
                          style: TextStyle(
                            color: Color(0xFF222222),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

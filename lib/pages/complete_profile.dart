import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Shown when a signed-in user doesn't yet have a role and/or phone
/// number on file -- this happens for Google sign-ins that started
/// from the login page (rather than the sign-up page), since Google
/// never gives us either of those.
class CompleteProfilePage extends StatefulWidget {
  final String uid;
  final String? existingRole;
  final VoidCallback onComplete;

  const CompleteProfilePage({
    super.key,
    required this.uid,
    required this.onComplete,
    this.existingRole,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _authService = AuthService();
  final _phoneController = TextEditingController();

  late String _selectedRole = widget.existingRole ?? 'donor';
  bool _isLoading = false;
  String? _errorMessage;

  static final RegExp _phonePattern = RegExp(r'^\+?[0-9\s\-\(\)]{7,15}$');

  Future<void> _handleSave() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !_phonePattern.hasMatch(phone)) {
      setState(() => _errorMessage = 'Enter a valid phone number.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.completeProfile(
        uid: widget.uid,
        role: _selectedRole,
        phoneNumber: phone,
      );
      widget.onComplete();
    } catch (e) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F7),
      appBar: AppBar(
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF222222),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text(
                'Just a couple more details',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF222222),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We need a phone number so donors and receivers can '
                'reach each other to coordinate pickups.',
                style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
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
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Phone number',
                        hintText: 'e.g. +1 555 123 4567',
                        prefixIcon: const Icon(Icons.phone_outlined),
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
                    const SizedBox(height: 22),
                    if (widget.existingRole == null) ...[
                      const Text(
                        'I am a:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 10),
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
                          title: const Text('Donor'),
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
                          title: const Text('Receiver'),
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
                    ],
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
                              onPressed: _handleSave,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'Continue',
                                style: TextStyle(
                                  fontSize: 16,
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

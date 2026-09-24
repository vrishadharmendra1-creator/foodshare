import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'login_page.dart';
import 'complete_profile.dart';
import 'donor.dart';
import 'receiver.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();

  // Bumping this forces the FutureBuilder below to re-fetch the user's
  // profile after CompleteProfilePage saves a role/phone number.
  int _profileRefreshToken = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<UserProfile>(
          key: ValueKey(_profileRefreshToken),
          future: _authService.getUserProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final profile = profileSnapshot.data ?? const UserProfile();

            // Missing role and/or phone number (typically a Google
            // sign-in that started from the login page) -- collect
            // whatever's missing before letting them into the app.
            if (!profile.isComplete) {
              return CompleteProfilePage(
                uid: user.uid,
                existingRole: profile.role,
                onComplete: () {
                  setState(() => _profileRefreshToken++);
                },
              );
            }

            if (profile.role == 'donor') {
              return const DonorPage();
            } else if (profile.role == 'receiver') {
              return const ReceiverPage();
            } else {
              return const LoginPage();
            }
          },
        );
      },
    );
  }
}

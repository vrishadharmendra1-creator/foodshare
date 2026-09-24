import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Simple holder for the pieces of a user's profile we care about.
class UserProfile {
  final String? role;
  final String? phoneNumber;
  const UserProfile({this.role, this.phoneNumber});

  /// True once the user has picked a role AND given us a phone number.
  /// Google sign-in can create a user doc before either of those exist,
  /// so this is what the app checks to decide whether to show the
  /// "complete your profile" screen.
  bool get isComplete =>
      role != null &&
      role!.isNotEmpty &&
      phoneNumber != null &&
      phoneNumber!.isNotEmpty;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleSignInInitialized = false;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUp({
    required String email,
    required String password,
    required String role,
    required String phoneNumber,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(credential.user!.uid).set({
      'email': email,
      'role': role,
      'phoneNumber': phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Signs in (or signs up) with Google. Google never gives us a phone
  /// number, so [phoneNumber] is optional here -- if it isn't supplied
  /// (e.g. the user tapped "Continue with Google" straight from the
  /// login page instead of the sign-up page), the user doc is created
  /// with a null role/phone and AuthWrapper will route them to the
  /// "complete your profile" screen until both are filled in.
  Future<UserCredential> signInWithGoogle({
    String? defaultRole,
    String? phoneNumber,
  }) async {
    await _ensureGoogleSignInInitialized();

    late final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw FirebaseAuthException(
          code: 'sign-in-cancelled',
          message: 'Google sign-in was cancelled.',
        );
      }
      throw FirebaseAuthException(
        code: 'google-sign-in-failed',
        message: e.description ?? 'Google sign-in failed.',
      );
    }

    final idToken = googleUser.authentication.idToken;

    final credential = GoogleAuthProvider.credential(idToken: idToken);

    final userCredential = await _auth.signInWithCredential(credential);

    final docRef = _db.collection('users').doc(userCredential.user!.uid);
    final doc = await docRef.get();

    if (!doc.exists) {
      await docRef.set({
        'email': userCredential.user!.email,
        'role': defaultRole,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (phoneNumber != null && phoneNumber.isNotEmpty) {
      // Returning user who is (re-)completing their profile.
      final data = doc.data();
      final updates = <String, dynamic>{};
      if (data?['phoneNumber'] == null) updates['phoneNumber'] = phoneNumber;
      if (defaultRole != null && data?['role'] == null) {
        updates['role'] = defaultRole;
      }
      if (updates.isNotEmpty) await docRef.update(updates);
    }

    return userCredential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // No-op: not signed in with Google, or not supported on this platform.
    }
  }

  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  Future<String?> getUserPhone(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['phoneNumber'] as String?;
  }

  /// Fetches role + phone together -- used by AuthWrapper to decide
  /// whether the signed-in user still needs to complete their profile.
  Future<UserProfile> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    final data = doc.data();
    return UserProfile(
      role: data?['role'] as String?,
      phoneNumber: data?['phoneNumber'] as String?,
    );
  }

  /// Fills in whatever is missing on a user's profile -- used by the
  /// "complete your profile" screen shown after a first-time Google
  /// sign-in that didn't already collect a role/phone number.
  Future<void> completeProfile({
    required String uid,
    required String role,
    required String phoneNumber,
  }) async {
    await _db.collection('users').doc(uid).set({
      'role': role,
      'phoneNumber': phoneNumber,
    }, SetOptions(merge: true));
  }

  static String friendlyAuthError(Object error) {
    print(error);
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
          return 'No account found with that email.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'email-already-in-use':
          return 'An account already exists with that email.';
        case 'weak-password':
          return 'Please choose a stronger password (6+ characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'Network error. Check your connection and try again.';
        case 'sign-in-cancelled':
          return 'Sign-in was cancelled.';
        case 'google-sign-in-failed':
          return 'Google sign-in failed. Please try again.';
        case 'account-exists-with-different-credential':
          return 'An account already exists with a different sign-in method.';
        default:
          return 'Something went wrong. Please try again.';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}

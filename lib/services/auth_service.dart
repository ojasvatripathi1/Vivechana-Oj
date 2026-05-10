import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../utils/logger.dart';

/// Key used to persist the anonymous UID so we can detect duplicate sessions.
const String _kAnonUidKey = 'anon_uid';

/// Centralised authentication service (singleton).
///
/// Reliability improvements:
///  - All public methods catch exceptions and re-throw only where the caller
///    explicitly needs to handle them (login UI shows the error message).
///  - Anonymous sign-in is idempotent — if an anonymous session already exists
///    for this device, the existing one is reused instead of creating a new account.
///  - `print()` is replaced with `debugPrint()` (stripped in release builds).
class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() => _instance;
  AuthService._internal() {
    // Automatically set Crashlytics user ID whenever auth state changes
    _auth.authStateChanges().listen((User? user) {
      if (user != null) {
        FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
        AppLogger.info('User session started: ${user.uid}', tag: 'AUTH');
      } else {
        FirebaseCrashlytics.instance.setUserIdentifier('');
        AppLogger.info('User session ended', tag: 'AUTH');
      }
    });
  }

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Auth state ───────────────────────────────────────────────────────────

  /// Stream of auth state changes — use this in an [AuthWrapper] StreamBuilder.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in [User], or null if nobody is signed in.
  User? get currentUser => _auth.currentUser;

  /// Convenience getter — true if any user (including anonymous) is signed in.
  bool get isLoggedIn => _auth.currentUser != null;

  // ── Sign-in methods ──────────────────────────────────────────────────────

  /// Sign in with a Google account (mobile only).
  ///
  /// Throws on failure so the calling UI can surface a user-facing message.
  Future<UserCredential?> signInWithGoogle() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      // Non-mobile platforms do not support the Google Sign-In plugin.
      throw UnsupportedError(
        'Google Sign-In is only supported on Android and iOS. '
        'Please use email/password authentication on this platform.',
      );
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the picker — not an error, just a cancellation.
        return null;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result = await _auth.signInWithCredential(credential);
      AppLogger.info('Google Sign-In succeeded: ${result.user?.uid}', tag: 'AUTH');
      AppLogger.action('login_success', parameters: {'method': 'google'});
      return result;
    } catch (e, stack) {
      AppLogger.error('Google Sign-In error', tag: 'AUTH', error: e, stackTrace: stack);
      rethrow; // Surface to UI for user-facing error display.
    }
  }

  /// Sign in with email and password (used for testing on non-mobile platforms
  /// and as a fallback auth method).
  ///
  /// Throws [FirebaseAuthException] on invalid credentials.
  Future<UserCredential?> testSignInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      AppLogger.info('Email sign-in succeeded: ${credential.user?.uid}', tag: 'AUTH');
      AppLogger.action('login_success', parameters: {'method': 'email'});
      return credential;
    } catch (e, stack) {
      AppLogger.error('Email sign-in error', tag: 'AUTH', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Sign in as an anonymous guest.
  ///
  /// **Idempotent** — if an anonymous session was previously created on this
  /// device and is still active in Firebase Auth, this method reuses it instead
  /// of creating a new account. This prevents unbounded anonymous account
  /// proliferation on low-memory devices that frequently kill the app process.
  ///
  /// Returns null if the user is already signed in (anonymous or otherwise),
  /// so the caller does not need to navigate again unnecessarily.
  Future<UserCredential?> signInAsGuest() async {
    // Case 1: Already signed in as anonymous — reuse the existing session.
    if (_auth.currentUser?.isAnonymous == true) {
      debugPrint('[AuthService] Reusing existing anonymous session: ${_auth.currentUser!.uid}');
      return null;
    }

    // Case 2: Already signed in as a real user — no action needed.
    if (_auth.currentUser != null) {
      debugPrint('[AuthService] Already signed in as real user: ${_auth.currentUser!.uid}');
      return null;
    }

    // Case 3: No active session. Check if we previously created an anon account
    // for this device (persisted in SharedPreferences).
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedAnonUid = prefs.getString(_kAnonUidKey);

      if (storedAnonUid != null) {
        // Try to sign in silently — if the anon account still exists in Firebase,
        // the SDK will restore the session automatically on next cold start via
        // the auth state persistence. We only reach here if the session was lost
        // (e.g., app was reinstalled). Create a fresh anon account.
        debugPrint('[AuthService] Previous anon UID found ($storedAnonUid) but no active session — creating new anon account.');
      }

      final credential = await _auth.signInAnonymously();
      // Persist the new anon UID so future cold starts can detect duplication.
      await prefs.setString(_kAnonUidKey, credential.user!.uid);
      AppLogger.info('Anonymous sign-in succeeded: ${credential.user?.uid}', tag: 'AUTH');
      AppLogger.action('login_success', parameters: {'method': 'anonymous'});
      return credential;
    } catch (e, stack) {
      AppLogger.error('Anonymous sign-in error', tag: 'AUTH', error: e, stackTrace: stack);
      rethrow;
    }
  }

  // ── Sign-out ─────────────────────────────────────────────────────────────

  /// Sign out the current user (both Firebase and Google Sign-In).
  ///
  /// Does not throw — sign-out failure should never block the user from
  /// returning to the login screen.
  Future<void> signOut() async {
    try {
      // Clear stored anonymous UID so the next guest login gets a fresh account.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAnonUidKey);

      await _googleSignIn.signOut();
      await _auth.signOut();
      AppLogger.info('Signed out successfully.', tag: 'AUTH');
      AppLogger.action('logout');
    } catch (e, stack) {
      // Non-critical — user is effectively logged out client-side regardless.
      AppLogger.warning('Sign-out error (non-fatal): $e', tag: 'AUTH');
    }
  }

  // ── User info helpers ────────────────────────────────────────────────────

  /// Returns a human-readable display name for the current user.
  /// Falls back to "अतिथि" for anonymous users, "उपयोगकर्ता" as last resort.
  String getCurrentUserDisplayName() {
    final displayName = _auth.currentUser?.displayName;
    if (displayName != null && displayName.isNotEmpty) return displayName;
    if (_auth.currentUser?.isAnonymous ?? false) return 'अतिथि';
    return 'उपयोगकर्ता';
  }

  /// Returns true if the current user is signed in anonymously.
  bool get isGuestUser => _auth.currentUser?.isAnonymous ?? false;

  /// Display name of the current user, or null if not signed in.
  String? getUserDisplayName() => _auth.currentUser?.displayName;

  /// Email of the current user, or null.
  String? getUserEmail() => _auth.currentUser?.email;

  /// Profile picture URL of the current user, or null.
  String? getUserPhotoURL() => _auth.currentUser?.photoURL;

  /// UID of the current user, or null.
  String? getUserUID() => _auth.currentUser?.uid;
}

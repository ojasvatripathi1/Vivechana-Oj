import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../utils/logger.dart';

class AccountService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Prompts the user to re-authenticate based on their provider (Google or Password)
  Future<bool> reauthenticateUser(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    AppLogger.action('reauthenticate_user_started', parameters: {'uid': user.uid});

    try {
      // Check if user signed in with Google
      final isGoogleAuth = user.providerData.any((userInfo) => userInfo.providerId == 'google.com');

      if (isGoogleAuth) {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return false; // User cancelled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        await user.reauthenticateWithCredential(credential);
        return true;
      } else {
        // Password auth
        final password = await _showPasswordDialog(context);
        if (password == null || password.isEmpty) return false;

        final AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );

        await user.reauthenticateWithCredential(credential);
        return true;
      }
    } on FirebaseAuthException catch (e) {
      AppLogger.error('Re-authentication failed: ${e.message}', tag: 'AccountService', error: e);
      _showErrorSnackBar(context, 'प्रमाणीकरण विफल रहा। कृपया पुनः प्रयास करें। (Error: ${e.message})');
      return false;
    } catch (e, stackTrace) {
      AppLogger.error('Unexpected error during re-auth', tag: 'AccountService', error: e, stackTrace: stackTrace);
      _showErrorSnackBar(context, 'कुछ गलत हो गया।');
      return false;
    }
  }

  /// Deletes the user account completely, following the proper safe order
  Future<void> deleteAccount(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');

    final uid = user.uid;
    AppLogger.action('delete_account_started', parameters: {'uid': uid});

    try {
      // 1. Re-authenticate
      final reauthSuccess = await reauthenticateUser(context);
      if (!reauthSuccess) {
        throw Exception('Re-authentication failed or was cancelled');
      }

      // Show a loading dialog so the user knows deletion is in progress
      _showLoadingDialog(context);

      // 2. Delete Firestore Data
      await _deleteFirestoreData(uid);

      // 3. Delete Storage Files
      await _deleteStorageData(uid);

      // 4. Delete Auth User
      await user.delete();

      AppLogger.action('delete_account_success', parameters: {'uid': uid});

      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('आपका खाता स्थायी रूप से हटा दिया गया है।')),
        );
        // Navigate to login
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e, stackTrace) {
      // Close loading dialog if open
      if (context.mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      AppLogger.error('Account deletion failed', tag: 'AccountService', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        _showErrorSnackBar(context, 'खाता हटाने में समस्या आई। कृपया बाद में प्रयास करें।');
      }
      rethrow;
    }
  }

  Future<void> _deleteFirestoreData(String uid) async {
    AppLogger.info('Deleting Firestore data for user: $uid', tag: 'AccountService');
    final batch = _firestore.batch();

    // Remove from main users collection
    final userRef = _firestore.collection('users').doc(uid);
    batch.delete(userRef);

    // If there are specific subcollections to delete, we must fetch and delete them
    // E.g., user_notifications, user_articles, or saved articles
    
    // Notifications
    final notifications = await _firestore.collection('users').doc(uid).collection('notifications').get();
    for (var doc in notifications.docs) {
      batch.delete(doc.reference);
    }
    
    // Example: user_articles or other top level collections linked to uid
    final articles = await _firestore.collection('articles').where('authorId', isEqualTo: uid).get();
    for (var doc in articles.docs) {
      batch.delete(doc.reference);
    }

    // Example: any history/saved
    final history = await _firestore.collection('users').doc(uid).collection('history').get();
    for (var doc in history.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    AppLogger.info('Firestore data deleted for user: $uid', tag: 'AccountService');
  }

  Future<void> _deleteStorageData(String uid) async {
    AppLogger.info('Deleting Storage data for user: $uid', tag: 'AccountService');
    try {
      final userFolderRef = _storage.ref().child('users/$uid');
      final listResult = await userFolderRef.listAll();
      
      for (var item in listResult.items) {
        await item.delete();
      }
      AppLogger.info('Storage data deleted for user: $uid', tag: 'AccountService');
    } catch (e) {
      // It's possible the folder doesn't exist, which is fine
      if (e is FirebaseException && e.code == 'object-not-found') {
        AppLogger.info('No storage data found for user: $uid', tag: 'AccountService');
      } else {
        AppLogger.error('Error deleting storage data', tag: 'AccountService', error: e);
        // Depending on requirements, we can rethrow or swallow. Usually we want to continue deletion.
      }
    }
  }

  Future<String?> _showPasswordDialog(BuildContext context) {
    String? password;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('पासवर्ड दर्ज करें'),
          content: TextField(
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'पासवर्ड',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => password = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('रद्द करें'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, password),
              child: const Text('पुष्टि करें'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('खाता हटाया जा रहा है... कृपया प्रतीक्षा करें।')),
            ],
          ),
        );
      },
    );
  }
}

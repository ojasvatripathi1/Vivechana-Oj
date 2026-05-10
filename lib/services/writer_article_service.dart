import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/writer_article.dart';
import 'storage_service.dart';

class WriterArticleService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'writer_articles';

  /// Fetch latest articles for the feed
  Future<List<WriterArticle>> getFeedArticles({int limit = 20, String? category}) async {
    try {
      // Bypass composite index: fetch ordered by date, then filter natively
      final snapshot = await _firestore.collection(_collectionName).orderBy('createdAt', descending: true).get();
      
      var articles = snapshot.docs.map((doc) => WriterArticle.fromMap(doc.id, doc.data())).toList();
      
      // Filter out non-approved articles from the public feed
      articles = articles.where((a) => a.status == 'approved').toList();

      if (category != null && category != 'सभी') {
        if (category == 'लेख') {
          articles = articles.where((a) => a.category == 'लेख' || a.category == 'संस्मरण').toList();
        } else {
          articles = articles.where((a) => a.category == category).toList();
        }
      }
      
      return articles.take(limit).toList();
    } catch (e) {
      debugPrint('Error fetching feed articles: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.isAnonymous) {
          FirebaseAuth.instance.signOut();
        }
      }
      return [];
    }
  }

  /// Fetch articles by a specific author
  Future<List<WriterArticle>> getArticlesByAuthor(String authorId, {bool onlyApproved = false}) async {
    try {
      // Bypass composite index 'authorId' + 'createdAt' by not ordering in the query
      final snapshot = await _firestore
          .collection(_collectionName)
          .where('authorId', isEqualTo: authorId)
          .get();
          
      var articles = snapshot.docs.map((doc) => WriterArticle.fromMap(doc.id, doc.data())).toList();
      
      // Sort natively by date descending
      articles.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      if (onlyApproved) {
        articles = articles.where((a) => a.status == 'approved').toList();
      }
      
      return articles;
    } catch (e) {
      debugPrint('Error fetching author articles: $e');
      if (e is FirebaseException && e.code == 'permission-denied') {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null && user.isAnonymous) {
          FirebaseAuth.instance.signOut();
        }
      }
      return [];
    }
  }
  
  /// Delete a specific article. If [notifyAuthorId] and [articleTitle] are provided,
  /// a notification will be sent to the author about the deletion.
  Future<bool> deleteArticle(String articleId, {String? coverImageUrl, String? notifyAuthorId, String? articleTitle, String? reason}) async {
    try {
      if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
        await deleteImageFromStorage(coverImageUrl);
      }
      await _firestore.collection(_collectionName).doc(articleId).delete();
      
      // If requested, notify the writer that their post was deleted
      if (notifyAuthorId != null && articleTitle != null) {
        try {
          String message = 'Admin removed your post "$articleTitle".';
          if (reason != null && reason.isNotEmpty) {
             message += ' Reason: $reason';
          }
          await _firestore.collection('user_notifications').add({
             'userId': notifyAuthorId,
             'title': 'Post Deleted by Admin',
             'body': message,
             'createdAt': FieldValue.serverTimestamp(),
             'isRead': false,
             'type': 'admin_deletion',
          });
        } catch (e) {
          debugPrint('Failed to send admin deletion notification: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error deleting article: $e');
      return false;
    }
  }

  /// Delete cover image from Firebase Storage by its download URL.
  Future<bool> deleteImageFromStorage(String imageUrl) async {
    try {
      await StorageService.deleteByUrl(imageUrl);
      return true;
    } catch (e) {
      debugPrint('deleteImageFromStorage error: $e');
      return false;
    }
  }

  /// Upload cover image to Firebase Storage with compression + 1 MB guard.
  /// Throws [StorageSizeError] if file exceeds 1 MB.
  Future<String?> uploadCoverImage(File imageFile) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = 'article_covers/$timestamp.jpg';
    return await StorageService.uploadArticleCover(
      file: imageFile,
      storagePath: storagePath,
    );
  }

  /// Submit a new article
  Future<String?> submitArticle(WriterArticle article) async {
    try {
      final docRef = await _firestore.collection(_collectionName).add(article.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error submitting article: $e');
      return null;
    }
  }

  /// Increment views
  Future<void> incrementViews(String articleId) async {
    try {
      await _firestore.collection(_collectionName).doc(articleId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing views: $e');
    }
  }

  /// Toggle like
  Future<void> incrementLike(String articleId) async {
     try {
      await _firestore.collection(_collectionName).doc(articleId).update({
        'likes': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing likes: $e');
    }
  }

  /// Fetch comments stream for an article
  Stream<QuerySnapshot> getCommentsStream(String articleId) {
    return _firestore
        .collection(_collectionName)
        .doc(articleId)
        .collection('comments')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Add a comment to an article
  Future<bool> addComment({
    required String articleId,
    required String text,
    required String authorId,
    required String authorName,
    String? authorImageUrl,
  }) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(articleId)
          .collection('comments')
          .add({
        'text': text,
        'authorId': authorId,
        'authorName': authorName,
        'authorImageUrl': authorImageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint('Error adding comment: $e');
      return false;
    }
  }

  /// Decrement like
  Future<void> decrementLike(String articleId) async {
     try {
      await _firestore.collection(_collectionName).doc(articleId).update({
        'likes': FieldValue.increment(-1),
      });
    } catch (e) {
      debugPrint('Error decrementing likes: $e');
    }
  }

  /// Delete a comment from an article
  Future<bool> deleteComment({required String articleId, required String commentId}) async {
    try {
      await _firestore
          .collection(_collectionName)
          .doc(articleId)
          .collection('comments')
          .doc(commentId)
          .delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  /// Report a comment for moderation
  Future<bool> reportComment({
    required String articleId,
    required String commentId,
    required String reason,
    required String reportedBy,
  }) async {
    try {
      await _firestore.collection('comment_reports').add({
        'articleId': articleId,
        'commentId': commentId,
        'reason': reason,
        'reportedBy': reportedBy,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Error reporting comment: $e');
      return false;
    }
  }

  /// Block a user (saves to a local user-specific block list in Firestore)
  Future<bool> blockUser({required String currentUserId, required String blockUserId}) async {
    try {
      await _firestore.collection('users').doc(currentUserId).update({
        'blockedUsers': FieldValue.arrayUnion([blockUserId]),
      });
      return true;
    } catch (e) {
      // If document doesn't have the field yet or doesn't exist
      try {
        await _firestore.collection('users').doc(currentUserId).set({
          'blockedUsers': [blockUserId],
        }, SetOptions(merge: true));
        return true;
      } catch (e2) {
        debugPrint('Error blocking user: $e2');
        return false;
      }
    }
  }
}

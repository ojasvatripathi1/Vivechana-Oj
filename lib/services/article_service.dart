import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/article.dart';

class ArticleService {
  static final ArticleService _instance = ArticleService._internal();

  factory ArticleService() {
    return _instance;
  }

  ArticleService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Save/bookmark an article for the current user
  Future<void> saveArticle(Article article) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to save articles');
    }

    try {
      final bookmarkRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .doc(article.id);

      final data = article.toJson();
      data['savedAt'] = FieldValue.serverTimestamp();
      await bookmarkRef.set(data);
    } catch (e) {
      throw Exception('Failed to save article: $e');
    }
  }

  /// Remove a saved article for the current user
  Future<void> removeArticle(String articleId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to remove saved articles');
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .doc(articleId)
          .delete();
    } catch (e) {
      throw Exception('Failed to remove article: $e');
    }
  }

  /// Check if an article is saved
  Future<bool> isArticleSaved(String articleId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .doc(articleId)
          .get();
      return doc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Get all saved articles for the current user
  Future<List<Article>> getSavedArticles() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User must be logged in to fetch saved articles');
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('saved_articles')
          .orderBy('savedAt', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Article(
          id: data['id'] ?? '',
          title: data['title'] ?? '',
          subtitle: data['subtitle'] ?? '',
          author: data['author'] ?? '',
          authorBio: data['authorBio'] ?? '',
          authorImage: data['authorImage'] ?? '',
          image: data['image'] ?? '',
          category: data['category'] ?? '',
          date: data['date'] ?? '',
          readTime: data['readTime'] ?? '',
          url: data['url'] ?? '',
          content: [],
          isPremium: data['isPremium'] ?? false,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch saved articles: $e');
    }
  }

  /// Stream of saved articles for real-time updates
  Stream<List<Article>> getSavedArticlesStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('saved_articles')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((querySnapshot) {
          return querySnapshot.docs.map((doc) {
            final data = doc.data();
            return Article(
              id: data['id'] ?? '',
              title: data['title'] ?? '',
              subtitle: data['subtitle'] ?? '',
              author: data['author'] ?? '',
              authorBio: data['authorBio'] ?? '',
              authorImage: data['authorImage'] ?? '',
              image: data['image'] ?? '',
              category: data['category'] ?? '',
              date: data['date'] ?? '',
              readTime: data['readTime'] ?? '',
              url: data['url'] ?? '',
              content: [],
              isPremium: data['isPremium'] ?? false,
            );
          }).toList();
        });
  }
}

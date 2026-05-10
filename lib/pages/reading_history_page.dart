import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import 'package:animate_do/animate_do.dart';

class ReadingHistoryPage extends StatefulWidget {
  const ReadingHistoryPage({super.key});

  @override
  State<ReadingHistoryPage> createState() => _ReadingHistoryPageState();
}

class _ReadingHistoryPageState extends State<ReadingHistoryPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final userId = _auth.currentUser?.uid;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        backgroundColor: DesignTokens.primary,
        title: const Text(
          'पढ़ने का इतिहास',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white),
            onPressed: () => _showClearHistoryDialog(isDark),
          ),
        ],
      ),
      body: userId == null
          ? _buildEmptyState(isDark)
          : StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('users')
                  .doc(userId)
                  .collection('reading_history')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('त्रुटि: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: _buildHistoryItemFromFirestore(context, doc, isDark),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeIn(
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryRed],
                ),
              ),
              child: const Icon(Icons.history, size: 64, color: Colors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'कोई पढ़ा गया लेख नहीं',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: DesignTokens.textPrimaryOn(isDark),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'आप जब भी कोई लेख पढ़ेंगे, वह यहाँ\nदिखाई देगा',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: DesignTokens.textSecondaryOn(isDark),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItemFromFirestore(
    BuildContext context,
    DocumentSnapshot doc,
    bool isDark,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] ?? 'अज्ञात लेख';
    final author = data['author'] ?? 'अज्ञात लेखक';
    final category = data['category'] ?? 'सामान्य';
    final timestamp = data['timestamp'] as Timestamp?;
    
    String readTmeDisplay = 'कुछ समय पहले';
    if (timestamp != null) {
      final now = DateTime.now();
      final diff = now.difference(timestamp.toDate());
      if (diff.inMinutes < 60) {
        readTmeDisplay = '${diff.inMinutes} मिनट पहले';
      } else if (diff.inHours < 24) {
        readTmeDisplay = '${diff.inHours} घंटे पहले';
      } else if (diff.inDays < 7) {
        readTmeDisplay = '${diff.inDays} दिन पहले';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Category badge
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                category.substring(0, 1),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      readTmeDisplay,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () async {
              await doc.reference.delete();
            },
            color: Colors.grey,
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.cardColorOn(isDark),
        title: Text(
          'इतिहास साफ़ करें',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'क्या आप पूरा पढ़ने का इतिहास हटाना चाहते हैं?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द करें'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close dialog immediately

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('इतिहास साफ़ किया जा रहा है...')),
              );

              final userId = _auth.currentUser?.uid;
              if (userId != null) {
                final collection = _firestore.collection('users').doc(userId).collection('reading_history');
                
                // Do deletion in background
                collection.get().then((snapshot) async {
                  final int batchSize = 400;
                  // Handle batches to overcome Firestore's 500 operation limit
                  for (int i = 0; i < snapshot.docs.length; i += batchSize) {
                    final int end = (i + batchSize < snapshot.docs.length) ? i + batchSize : snapshot.docs.length;
                    final WriteBatch batch = _firestore.batch();
                    for (int j = i; j < end; j++) {
                      batch.delete(snapshot.docs[j].reference);
                    }
                    await batch.commit();
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('इतिहास सफलतापूर्वक साफ़ किया गया')),
                    );
                  }
                }).catchError((e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('हटाने में त्रुटि: $e')),
                    );
                  }
                });
              }
            },
            child: const Text(
              'साफ़ करें',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/writer_article_service.dart';

class ArticleCommentsSheet extends StatefulWidget {
  final String articleId;

  const ArticleCommentsSheet({super.key, required this.articleId});

  @override
  State<ArticleCommentsSheet> createState() => _ArticleCommentsSheetState();
}

class _ArticleCommentsSheetState extends State<ArticleCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  final WriterArticleService _articleService = WriterArticleService();
  bool _isSubmitting = false;

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('टिप्पणी करने के लिए लॉगिन करें।')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Get user details from Firestore directly or use Firebase Auth profile
    String authorName = user.displayName ?? 'उपयोगकर्ता';
    
    // We try to fetch the latest details from "users" collection for full fidelity
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
         authorName = userDoc.data()!['fullName'] ?? authorName;
      }
    } catch (e) {
       debugPrint('Could not fetch user doc for name: $e');
    }

    final success = await _articleService.addComment(
      articleId: widget.articleId,
      text: text,
      authorId: user.uid,
      authorName: authorName,
      authorImageUrl: user.photoURL,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _commentController.clear();
        FocusScope.of(context).unfocus(); // hide keyboard
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('टिप्पणी पोस्ट नहीं की जा सकी।')),
        );
      }
    }
  }

  Future<void> _confirmDeleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('टिप्पणी हटाएं?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('क्या आप वाकई इस टिप्पणी को हटाना चाहते हैं? यह कार्रवाई पूर्ववत नहीं की जा सकती।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('रद्द करें', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('हटाएं', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _articleService.deleteComment(
        articleId: widget.articleId,
        commentId: commentId,
      );
      if (mounted && !success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('टिप्पणी हटाने में त्रुटि हुई।'), backgroundColor: Colors.red),
        );
      }
    }
  }

  List<String> _blockedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['blockedUsers'] != null) {
        setState(() {
          _blockedUsers = List<String>.from(doc.data()!['blockedUsers']);
        });
      }
    } catch (e) {
      debugPrint('Error fetching blocked users: $e');
    }
  }

  Future<void> _reportComment(String commentId, String authorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final List<String> reasons = [
      'अभद्र भाषा (Abusive)',
      'स्पैम (Spam)',
      'अनुचित सामग्री (Inappropriate)',
      'अन्य (Other)'
    ];
    String selectedReason = reasons[0];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('रिपोर्ट करें', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: reasons
                .map((r) => RadioListTile<String>(
                      title: Text(r),
                      value: r,
                      groupValue: selectedReason,
                      onChanged: (val) => setDialogState(() => selectedReason = val!),
                    ))
                .toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करें')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('रिपोर्ट भेजें',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final success = await _articleService.reportComment(
        articleId: widget.articleId,
        commentId: commentId,
        reason: selectedReason,
        reportedBy: user.uid,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'रिपोर्ट दर्ज की गई। धन्यवाद।' : 'रिपोर्ट भेजने में त्रुटि।'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(String blockUserId, String blockUserName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$blockUserName को ब्लॉक करें?'),
        content: const Text('ब्लॉक करने के बाद आपको इस उपयोगकर्ता की टिप्पणियां दिखाई नहीं देंगी।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('रद्द करें')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ब्लॉक करें', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _articleService.blockUser(
        currentUserId: user.uid,
        blockUserId: blockUserId,
      );

      if (success) {
        setState(() {
          _blockedUsers.add(blockUserId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('उपयोगकर्ता को ब्लॉक कर दिया गया है।')),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark; // Forced Light Mode
    
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.85, // Add a fixed height constraint
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // adjusts for keyboard
      ),
      decoration: BoxDecoration(
        color: DesignTokens.scaffoldOn(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.dividerOn(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          Text(
            'टिप्पणियां',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: DesignTokens.textPrimaryOn(isDark),
            ),
          ),
          
          Divider(color: DesignTokens.dividerOn(isDark), height: 24),

          // Comments List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _articleService.getCommentsStream(widget.articleId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return const Center(child: Text('टिप्पणियां लोड करने में त्रुटि।'));
                }

                // Filter out blocked users
                final allDocs = snapshot.data?.docs ?? [];
                final docs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final authorId = data['authorId'] ?? '';
                  return !_blockedUsers.contains(authorId);
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        allDocs.isEmpty
                            ? 'अभी तक कोई टिप्पणी नहीं है। पहली टिप्पणी करें!'
                            : 'ब्लॉक की गई टिप्पणियां छिपी हुई हैं।',
                        style: TextStyle(color: DesignTokens.textSecondaryOn(isDark)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final currentUser = FirebaseAuth.instance.currentUser;
                
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String commentId = docs[index].id;
                    
                    final String text = data['text'] ?? '';
                    final String authorName = data['authorName'] ?? 'Unknown';
                    final String? authorImageUrl = data['authorImageUrl'];
                    final String commentAuthorId = data['authorId'] ?? '';
                    
                    final ts = data['timestamp'] as Timestamp?;
                    final date = ts != null ? ts.toDate() : DateTime.now();
                    final String timeAgoStr = timeago.format(date, locale: 'hi');
                    
                    final bool isOwnComment = currentUser != null && currentUser.uid == commentAuthorId;
                    
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primaryLight.withOpacity(0.1),
                          backgroundImage: authorImageUrl != null ? NetworkImage(authorImageUrl) : null,
                          child: authorImageUrl == null 
                            ? const Icon(Icons.person, size: 20, color: AppColors.primaryLight)
                            : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.primaryDark : Colors.grey.shade100,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        authorName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: DesignTokens.textPrimaryOn(isDark),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          timeAgoStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: DesignTokens.textSecondaryOn(isDark),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        if (isOwnComment)
                                          GestureDetector(
                                            onTap: () => _confirmDeleteComment(commentId),
                                            child: Icon(
                                              Icons.delete_outline_rounded,
                                              size: 18,
                                              color: Colors.red.shade400,
                                            ),
                                          )
                                        else
                                          PopupMenuButton<String>(
                                            icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 120),
                                            onSelected: (val) {
                                              if (val == 'report') _reportComment(commentId, commentAuthorId);
                                              if (val == 'block') _blockUser(commentAuthorId, authorName);
                                            },
                                            itemBuilder: (ctx) => [
                                              const PopupMenuItem(
                                                value: 'report',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.report_problem_outlined, size: 18, color: Colors.orange),
                                                    SizedBox(width: 8),
                                                    Text('रिपोर्ट करें', style: TextStyle(fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'block',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.block_flipped, size: 18, color: Colors.red),
                                                    SizedBox(width: 8),
                                                    Text('ब्लॉक करें', style: TextStyle(fontSize: 13)),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  text,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: DesignTokens.textPrimaryOn(isDark).withOpacity(0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          
          // Comment Input Field
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
            decoration: BoxDecoration(
              color: DesignTokens.scaffoldOn(isDark),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 10,
                )
              ]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: DesignTokens.textPrimaryOn(isDark)),
                    decoration: InputDecoration(
                      hintText: 'अपनी टिप्पणी यहां लिखें...',
                      hintStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark)),
                      filled: true,
                      fillColor: DesignTokens.cardColorOn(isDark),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
                const SizedBox(width: 8),
                _isSubmitting
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 24, height: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.send_rounded, color: AppColors.primaryRed),
                        onPressed: _submitComment,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

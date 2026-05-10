import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../models/writer_article.dart';
import '../services/auth_service.dart';
import '../services/writer_article_service.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'admin_publish_magazine_tab.dart';
import 'admin_news_reels_tab.dart';
import 'admin_reports_tab.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _articleService = WriterArticleService();

  // ──────────────────────────────────────────────────────────
  // writer_registrations tab
  // ──────────────────────────────────────────────────────────
  Widget _buildPendingWritersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('त्रुटि (Error)'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('कोई आवेदन लंबित नहीं है (No pending applications)', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         if (data['profileImageUrl'] != null) 
                           CircleAvatar(backgroundImage: NetworkImage(data['profileImageUrl']!), radius: 24)
                         else
                           const CircleAvatar(backgroundColor: Colors.grey, radius: 24, child: Icon(Icons.person, color: Colors.white)),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(data['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               Text("फ़ोन (Phone): ${data['phoneNumber'] ?? data['phone'] ?? ''}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                               Text("आधार नंबर (Aadhar): ${data['aadharNumber'] ?? ''}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                             ],
                           ),
                         ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('परिचय (Bio):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(data['bio'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 16),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         TextButton(
                           onPressed: () => _rejectWriterRegistration(doc.id),
                           style: TextButton.styleFrom(foregroundColor: Colors.red),
                           child: const Text('अस्वीकार करें (Reject)'),
                         ),
                         const SizedBox(width: 8),
                         ElevatedButton(
                           onPressed: () => _approveWriterRegistration(doc.id, data['uid'], data['penName'], data['fullName']),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green,
                             foregroundColor: Colors.white,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                           child: const Text('स्वीकार करें (Approve)'),
                         ),
                       ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approveWriterRegistration(String docId, String? uid, String? penName, String? fullName) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update registration document
      final regRef = FirebaseFirestore.instance.collection('writer_registrations').doc(docId);
      batch.update(regRef, {'status': 'approved'});
      
      // Update users collection
      if (uid != null) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final writerName = (penName != null && penName.isNotEmpty) ? penName : fullName;
        batch.set(userRef, {
          'isWriter': true,
          'writerName': writerName ?? 'Unknown Writer',
        }, SetOptions(merge: true));
      }

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('लेखक आवेदन स्वीकृत हुआ (Approved)'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectWriterRegistration(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('आवेदन अस्वीकार करें'),
        content: const Text('क्या आप वाकई इस लेखक आवेदन को अस्वीकार करना चाहते हैं? यह डेटा Firestore से हटा दिया जाएगा।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('अस्वीकार करें'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('writer_registrations').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('लेखक आवेदन अस्वीकृत व हटा दिया गया'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ──────────────────────────────────────────────────────────
  // Approved Writers list (Active Writers)
  // ──────────────────────────────────────────────────────────
  Widget _buildApprovedWritersTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('status', isEqualTo: 'approved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('त्रुटि (Error)'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text('कोई सक्रिय लेखक नहीं है (No active writers)', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final uid = data['uid'] ?? '';
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                         if (data['profileImageUrl'] != null) 
                           CircleAvatar(backgroundImage: NetworkImage(data['profileImageUrl']!), radius: 24)
                         else
                           const CircleAvatar(backgroundColor: Colors.grey, radius: 24, child: Icon(Icons.person, color: Colors.white)),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(data['fullName'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               Text("फ़ोन: ${data['phoneNumber'] ?? data['phone'] ?? ''}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                               Text("आधार नंबर: ${data['aadharNumber'] ?? ''}", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                             ],
                           ),
                         ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text('परिचय (Bio):', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(data['bio'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(height: 16),
                    FutureBuilder<List<WriterArticle>>(
                      future: uid.isNotEmpty ? _articleService.getArticlesByAuthor(uid) : Future.value([]),
                      builder: (context, idxSnap) {
                        if (idxSnap.connectionState == ConnectionState.waiting) {
                          return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)));
                        }
                        final articles = idxSnap.data ?? [];
                        if (articles.isEmpty) {
                           return Text('कोई रचना प्रकाशित नहीं की है (0 Articles)', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic));
                        }
                        return Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text('इनकी रचनाएँ (${articles.length}):', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryRed)),
                             const SizedBox(height: 8),
                             ...articles.map((a) => Padding(
                               padding: const EdgeInsets.only(bottom: 4),
                               child: Row(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   const Icon(Icons.article_outlined, size: 14, color: Colors.grey),
                                   const SizedBox(width: 4),
                                   Expanded(child: Text(a.title, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                 ],
                               ),
                             )),
                           ],
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                       alignment: Alignment.centerRight,
                       child: TextButton.icon(
                         onPressed: () => _removeWriterWithReason(doc.id, uid, data['fullName'] ?? 'Writer'),
                         style: TextButton.styleFrom(foregroundColor: Colors.red),
                         icon: const Icon(Icons.person_remove_rounded, size: 18),
                         label: const Text('निलंबित करें (Remove)'),
                       ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeWriterWithReason(String docId, String uid, String writerName) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('लेखक निलंबित करें: $writerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('कृपया लेखक को निलंबित करने का अचूक कारण दर्ज करें। यह कारण केवल इसी लेखक को उनकी स्वयं की प्रोफ़ाइल पर दिखाई देगा:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'हटाने का कारण...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () {
               if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('कृपया कारण अवश्य दर्ज करें।')));
                  return;
               }
               Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('निलंबित करें'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      
      // Update registration document to rejected with reason explicitly captured
      final regRef = FirebaseFirestore.instance.collection('writer_registrations').doc(docId);
      batch.update(regRef, {
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim(),
      });
      
      // Explicitly downgrade privileges inside primary users database
      if (uid.isNotEmpty) {
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        batch.set(userRef, {'isWriter': false}, SetOptions(merge: true));
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('लेखक सफलतापूर्वक निलंबित कर दिया गया है।'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ──────────────────────────────────────────────────────────
  // writer_articles tab
  // ──────────────────────────────────────────────────────────
  Widget _buildPendingArticlesTab() {
    return StreamBuilder<QuerySnapshot>(
      // Warning: In firestore, if we search where status == 'pending' and we didn't add the field to old documents,
      // they might not show up. But since we want to review NEW ones explicitly, this is correct.
      stream: FirebaseFirestore.instance
          .collection('writer_articles')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text('त्रुटि (Error)'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
           return const Center(child: Text('कोई रचना लंबित नहीं है (No pending articles)', style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final article = WriterArticle.fromMap(doc.id, doc.data() as Map<String, dynamic>);
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      maxLines: 2, overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (article.authorImageUrl != null)
                          CircleAvatar(backgroundImage: NetworkImage(article.authorImageUrl!), radius: 10)
                        else
                          const Icon(Icons.person, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Text(article.authorName, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                          child: Text(article.category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Text(
                      article.plainTextContent,
                      style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                      maxLines: 4, overflow: TextOverflow.ellipsis,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => _showFullArticle(article),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('पूरा पढ़ें'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.primaryLight, padding: EdgeInsets.zero),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                       mainAxisAlignment: MainAxisAlignment.end,
                       children: [
                         TextButton(
                           onPressed: () => _rejectArticle(doc.id, coverImageUrl: article.coverImageUrl, authorId: article.authorId, title: article.title),
                           style: TextButton.styleFrom(foregroundColor: Colors.red),
                           child: const Text('अस्वीकार करें (Reject)'),
                         ),
                         const SizedBox(width: 8),
                         ElevatedButton(
                           onPressed: () => _approveArticle(doc.id),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.green,
                             foregroundColor: Colors.white,
                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           ),
                           child: const Text('स्वीकार करें (Approve)'),
                         ),
                       ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFullArticle(WriterArticle article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header with approve/reject
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        article.category,
                        style: const TextStyle(color: AppColors.primaryRed, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _rejectArticle(article.id, coverImageUrl: article.coverImageUrl, authorId: article.authorId, title: article.title);
                      },
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('अस्वीकार'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _approveArticle(article.id);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('स्वीकार'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    // Cover image
                    if (article.coverImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          article.coverImageUrl!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    if (article.coverImageUrl != null) const SizedBox(height: 20),
                    // Title
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black87,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Author row
                    Row(
                      children: [
                        if (article.authorImageUrl != null)
                          CircleAvatar(backgroundImage: NetworkImage(article.authorImageUrl!), radius: 16)
                        else
                          const CircleAvatar(backgroundColor: Colors.grey, radius: 16, child: Icon(Icons.person, color: Colors.white, size: 16)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(article.authorName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            Text(
                              DateFormat('d MMM yyyy').format(article.createdAt),
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 16),
                    // Full content
                    Text(
                      article.plainTextContent,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
    );
  }

  Future<void> _approveArticle(String articleId) async {
    try {
      await FirebaseFirestore.instance.collection('writer_articles').doc(articleId).update({'status': 'approved'});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('रचना प्रकाशित हुई (Article Approved)'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _rejectArticle(String articleId, {String? coverImageUrl, String? authorId, String? title}) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('रचना अस्वीकार करें'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('कृपया रचना को अस्वीकार करने का कारण दर्ज करें। यह कारण केवल लेखक को दिखाई देगा:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'अस्वीकार करने का कारण...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            onPressed: () {
               if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('कृपया कारण अवश्य दर्ज करें।')));
                  return;
               }
               Navigator.pop(ctx, true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('अस्वीकार करें'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await FirebaseFirestore.instance.collection('writer_articles').doc(articleId).update({
        'status': 'rejected',
        'rejectionReason': reasonController.text.trim(),
      });
      
      // Notify the author if details were provided
      if (authorId != null && title != null) {
         try {
            await FirebaseFirestore.instance.collection('user_notifications').add({
               'userId': authorId,
               'title': 'रचना अस्वीकृत (Article Rejected)',
               'body': 'Admin rejected your post "$title". Reason: ${reasonController.text.trim()}',
               'createdAt': FieldValue.serverTimestamp(),
               'isRead': false,
               'type': 'admin_rejection',
            });
         } catch(e) {
            debugPrint('Failed to send rejection notification: $e');
         }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('रचना अस्वीकृत कर दी गई'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  // ──────────────────────────────────────────────────────────
  // Announcements (सूचनाएँ) tab
  // ──────────────────────────────────────────────────────────
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isPosting = false;

  Widget _buildAnnouncementsTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        // ── Post form ──────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'नई सूचना पोस्ट करें',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'शीर्षक (Title)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'विवरण (Body)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isPosting ? null : _postAnnouncement,
                  icon: _isPosting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.campaign_rounded, size: 18),
                  label: const Text('सूचना प्रकाशित करें'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
        // ── Recent announcements list ───────────────────────
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'हाल की सूचनाएँ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
              }
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'अभी कोई सूचना नहीं है।',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? '';
                  final body = data['body'] as String? ?? '';
                  final ts = data['createdAt'] as Timestamp?;
                  final dateStr = ts != null
                      ? DateFormat('d MMM yyyy, h:mm a').format(ts.toDate())
                      : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.campaign_rounded, color: AppColors.primaryRed, size: 20),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (body.isNotEmpty)
                            Text(
                              body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            dateStr,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        tooltip: 'हटाएँ',
                        onPressed: () => _deleteAnnouncement(doc.id, title),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _postAnnouncement() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('शीर्षक आवश्यक है।')),
      );
      return;
    }

    setState(() => _isPosting = true);
    try {
      // Get current admin name/email
      final user = AuthService().currentUser;
      final postedBy = user?.displayName ?? user?.email ?? 'प्रशासन';

      await FirebaseFirestore.instance.collection('announcements').add({
        'title': title,
        'body': body,
        'createdAt': FieldValue.serverTimestamp(),
        'postedBy': postedBy,
      });

      _titleController.clear();
      _bodyController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('सूचना सफलतापूर्वक प्रकाशित हुई!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _deleteAnnouncement(String docId, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('सूचना हटाएँ'),
        content: Text('"$title" को हटाना चाहते हैं?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('रद्द करें'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('हटाएँ'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('announcements').doc(docId).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('सूचना हटा दी गई।')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Tab _buildModernTab(IconData icon, String text) {
    return Tab(
      height: 42,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(text),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        appBar: AppBar(
          elevation: 4,
          shadowColor: Colors.black45,
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.appbarGradient)),
          title: Text(
            'एडमिन डैशबोर्ड (Admin)',
            style: GoogleFonts.notoSansDevanagari(fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: TabBar(
            isScrollable: true,
            labelColor: isDark ? Colors.white : AppColors.primaryRed,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorSize: TabBarIndicatorSize.label,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6), // Gaps between pills
            indicator: BoxDecoration(
              color: isDark ? AppColors.primaryRed : Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                 BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.15), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            splashBorderRadius: BorderRadius.circular(30),
            padding: const EdgeInsets.only(bottom: 12, left: 16, right: 16),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.2),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
            tabs: [
              _buildModernTab(Icons.person_add_alt_1_rounded, 'लेखक आवेदन'),
              _buildModernTab(Icons.people_alt_rounded, 'सक्रिय लेखक'),
              _buildModernTab(Icons.article_rounded, 'रचनाएँ'),
              _buildModernTab(Icons.campaign_rounded, 'सूचनाएँ'),
              _buildModernTab(Icons.menu_book_rounded, 'मैगज़ीन प्रकाशित करें'),
              _buildModernTab(Icons.video_library_rounded, 'न्यूज़ रील्स'),
              _buildModernTab(Icons.analytics_rounded, 'रिपोर्ट्स'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildPendingWritersTab(),
            _buildApprovedWritersTab(),
            _buildPendingArticlesTab(),
            _buildAnnouncementsTab(),
            const AdminPublishMagazineTab(),
            const AdminNewsReelsTab(),
            const AdminReportsTab(),
          ],
        ),
      ),
    );
  }
}

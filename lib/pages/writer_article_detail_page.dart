import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';

import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../widgets/article_comments_sheet.dart';
import '../models/writer_article.dart';
import '../services/writer_article_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'writer_profile_page.dart';

class WriterArticleDetailPage extends StatefulWidget {
  final WriterArticle article;

  const WriterArticleDetailPage({super.key, required this.article});

  @override
  State<WriterArticleDetailPage> createState() => _WriterArticleDetailPageState();
}

class _WriterArticleDetailPageState extends State<WriterArticleDetailPage> {
  final WriterArticleService _articleService = WriterArticleService();
  bool _hasLiked = false;
  int _localLikes = 0;
  bool _isLiking = false;
  String? _fetchedAuthorImage;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _localLikes = widget.article.likes;
    _fetchedAuthorImage = widget.article.authorImageUrl;
    
    // Increment view count on open
    _articleService.incrementViews(widget.article.id);
    _recordReadingHistory();
    _checkIfLiked();
    if (_fetchedAuthorImage == null || _fetchedAuthorImage!.contains('ui-avatars.com')) {
      _fetchAuthorImage();
    }
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          final bool isAdmin = userDoc.data()?['isAdmin'] == true || user.email == 'vivechanaoaj@gmail.com';
          if (mounted) {
            setState(() => _isAdmin = isAdmin);
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _fetchAuthorImage() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('uid', isEqualTo: widget.article.authorId)
          .limit(1)
          .get();
      if (doc.docs.isNotEmpty) {
        final data = doc.docs.first.data();
        if (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty) {
          if (mounted) setState(() => _fetchedAuthorImage = data['profileImageUrl']);
        }
      }
    } catch (e) {
      debugPrint('Error fetching author image: $e');
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('writer_articles')
          .doc(widget.article.id)
          .collection('likes')
          .doc(user.uid)
          .get();
          
      if (doc.exists && mounted) {
        setState(() {
          _hasLiked = true;
        });
      }
    } catch (e) {
      debugPrint('Error checking like status: $e');
    }
  }

  Future<void> _recordReadingHistory() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reading_history')
          .doc(widget.article.id);
          
      await docRef.set({
        'title': widget.article.title,
        'author': widget.article.authorName,
        'category': widget.article.category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving reading history: $e');
    }
  }

  Future<void> _handleLike() async {
    if (_isLiking) return;
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('पसंद करने के लिए लॉगिन करें।')),
      );
      return;
    }
    
    setState(() => _isLiking = true);
    
    if (_hasLiked) {
      // Unlike logic
      setState(() {
        _hasLiked = false;
        _localLikes = (_localLikes > 0) ? _localLikes - 1 : 0;
      });
      
      try {
        await FirebaseFirestore.instance
            .collection('writer_articles')
            .doc(widget.article.id)
            .collection('likes')
            .doc(user.uid)
            .delete();
            
        await _articleService.decrementLike(widget.article.id);
      } catch (e) {
        debugPrint('Error removing like: $e');
        // Rollback state visually if failed
        setState(() {
          _hasLiked = true;
          _localLikes++;
        });
      }
    } else {
      // Like logic
      setState(() {
        _hasLiked = true;
        _localLikes++;
      });
      
      try {
        await FirebaseFirestore.instance
            .collection('writer_articles')
            .doc(widget.article.id)
            .collection('likes')
            .doc(user.uid)
            .set({
          'timestamp': FieldValue.serverTimestamp(),
        });
        
        await _articleService.incrementLike(widget.article.id);
      } catch (e) {
        debugPrint('Error saving like: $e');
        // Rollback state visually if failed
        setState(() {
          _hasLiked = false;
          _localLikes = (_localLikes > 0) ? _localLikes - 1 : 0;
        });
      }
    }
    
    if (mounted) {
      setState(() => _isLiking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show exact publication date instead of relative time
    final String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(widget.article.createdAt);
    final bool isDark = Theme.of(context).brightness == Brightness.dark; // Forced Light Mode
    
    
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, widget.article.copyWith(
          likes: _localLikes,
        ));
        return false;
      },
      child: Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // 1. Sleek Hero Header
              _buildHeroAppBar(isDark),
              
              // 2. Main Content Sheet
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: DesignTokens.scaffoldOn(isDark),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  transform: Matrix4.translationValues(0.0, -30.0, 0.0),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 120), // Extra bottom padding for floating bar
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Badge
                        FadeInDown(
                          duration: const Duration(milliseconds: 400),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
                            ),
                            child: Text(
                              widget.article.category,
                              style: const TextStyle(
                                color: AppColors.primaryRed,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Title
                        FadeIn(
                          duration: const Duration(milliseconds: 500),
                          child: Text(
                            widget.article.title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              height: 1.3,
                              letterSpacing: -0.5,
                              color: DesignTokens.textPrimaryOn(isDark),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Author Interactive Row
                        FadeInUp(
                          duration: const Duration(milliseconds: 600),
                          child: _buildAuthorInfoCard(formattedDate, isDark),
                        ),
                        
                        const SizedBox(height: 32),
                        Divider(color: DesignTokens.dividerOn(isDark)),
                        const SizedBox(height: 32),
                        
                        // Article Body Content
                        FadeInUp(
                          duration: const Duration(milliseconds: 800),
                          child: _buildArticleContent(isDark),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          // 3. Floating Bottom Action Bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: _buildFloatingActionBar(isDark),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildArticleContent(bool isDark) {
    final content = widget.article.content;
    
    // Check if content is Delta JSON (from flutter_quill)
    if (content.trimLeft().startsWith('[{')) {
      try {
        final deltaJson = jsonDecode(content);
        final doc = Document.fromJson(deltaJson);
        final controller = QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        return QuillEditor(
          controller: controller,
          focusNode: FocusNode(),
          scrollController: ScrollController(),
          config: QuillEditorConfig(
            showCursor: false,
            autoFocus: false,
            expands: false,
            scrollable: false,
            padding: EdgeInsets.zero,
            customStyles: DefaultStyles(
              paragraph: DefaultTextBlockStyle(
                GoogleFonts.notoSansDevanagari(
                  fontSize: 17.5,
                  height: 1.9,
                  letterSpacing: 0.2,
                  color: DesignTokens.textPrimaryOn(isDark).withOpacity(0.9),
                ),
                const HorizontalSpacing(0, 0),
                const VerticalSpacing(6, 6),
                const VerticalSpacing(0, 0),
                null,
              ),
              h1: DefaultTextBlockStyle(
                GoogleFonts.notoSansDevanagari(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primaryDark, height: 1.4),
                const HorizontalSpacing(0, 0),
                const VerticalSpacing(16, 8),
                const VerticalSpacing(0, 0),
                null,
              ),
              h2: DefaultTextBlockStyle(
                GoogleFonts.notoSansDevanagari(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primaryDark, height: 1.4),
                const HorizontalSpacing(0, 0),
                const VerticalSpacing(12, 6),
                const VerticalSpacing(0, 0),
                null,
              ),
              bold: const TextStyle(fontWeight: FontWeight.w900),
              italic: const TextStyle(fontStyle: FontStyle.italic),
              underline: const TextStyle(decoration: TextDecoration.underline),
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error parsing Delta JSON: $e');
      }
    }
    
    // Fallback: plain text
    return Text(
      content,
      style: GoogleFonts.notoSansDevanagari(
        fontSize: 17.5,
        height: 1.9,
        letterSpacing: 0.2,
        color: DesignTokens.textPrimaryOn(isDark).withOpacity(0.9),
      ),
    );
  }

  Widget _buildHeroAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: widget.article.coverImageUrl != null ? 350.0 : 120.0,
      pinned: true,
      stretch: true,
      backgroundColor: AppColors.primaryDark,
      iconTheme: const IconThemeData(color: Colors.white),
      elevation: 0,
      // Custom back button background to ensure visibility over images
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              // Return the updated article back to the Feed/Profile so it doesn't reset locally
              Navigator.pop(context, widget.article.copyWith(
                likes: _localLikes,
              ));
            },
          ),
        ),
      ),
      actions: [
        if (FirebaseAuth.instance.currentUser?.uid == widget.article.authorId || _isAdmin)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white),
                onPressed: () => _confirmDelete(),
              ),
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.article.coverImageUrl != null)
              Image.network(
                widget.article.coverImageUrl!,
                fit: BoxFit.cover,
              )
            else
              Container(decoration: const BoxDecoration(gradient: AppColors.appbarGradient)),
              
            // Premium dark gradient overlay so text/icons pop 
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.5),
                    Colors.transparent,
                    Colors.black.withOpacity(0.2), // slight shadow at bottom to blend with white rounded top
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorInfoCard(String formattedDate, bool isDark) {
    final displayUrl = (_fetchedAuthorImage != null && _fetchedAuthorImage!.isNotEmpty)
        ? _fetchedAuthorImage!
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.article.authorName)}&background=9B0B1E&color=fff&size=128&bold=true';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          )
        ],
        border: Border.all(color: DesignTokens.dividerOn(isDark).withOpacity(0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            // First we show a loading dialog or just eagerly navigate if we load inline.
            // But since this query is fast, querying then pushing is fine.
            final docIdStr = widget.article.authorId;
            try {
              final doc = await FirebaseFirestore.instance
                  .collection('writer_registrations')
                  .where('uid', isEqualTo: docIdStr)
                  .limit(1)
                  .get();
                  
              if (!mounted) return;

              Map<String, String> writerMap;
              
              if (doc.docs.isNotEmpty) {
                final data = doc.docs.first.data();
                final fullName = data['fullName'] as String? ?? '';
                final penName = data['penName'] as String? ?? '';
                final name = penName.isNotEmpty ? penName : fullName;
                
                final genres = List<String>.from(data['preferredGenres'] ?? []);
                final designation = genres.isNotEmpty ? '${genres.first} लेखक' : 'लेखक';
                
                final String rawBio = data['bio'] as String? ?? '';
                final String bio = rawBio.isNotEmpty ? rawBio : '';
                String quote = bio.trim().replaceAll('\n', ' ');
                if (quote.length > 60) {
                  quote = '${quote.substring(0, 57)}...';
                } else if (quote.isEmpty) quote = 'विवेचना-ओज के एक मूल्यवान लेखक।';
                
                final image = data['profileImageUrl'] as String? ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=9B0B1E&color=fff&size=128&bold=true';
                final gender = data['gender'] as String? ?? '';
                
                writerMap = {
                  'name': name,
                  'designation': designation,
                  'quote': quote,
                  'bio': bio,
                  'gender': gender,
                  'image': image,
                  'uid': docIdStr,
                };
              } else {
                // Fallback if not registered formally
                writerMap = {
                  'name': widget.article.authorName,
                  'designation': 'लेखक',
                  'quote': 'विवेचना-ओज के एक मूल्यवान लेखक।',
                  'bio': 'विवेचना-ओज के एक सम्मानित रचनाकार, जिनकी रचनाएँ पाठकों को गहराई से प्रभावित करती हैं।',
                  'gender': '',
                  'image': _fetchedAuthorImage ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(widget.article.authorName)}&background=9B0B1E&color=fff&size=128&bold=true',
                  'uid': docIdStr,
                };
              }

              Navigator.push(context, MaterialPageRoute(
                builder: (context) => WriterProfilePage(writer: writerMap),
              ));
            } catch (e) {
              debugPrint('Error navigating to profile: $e');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryRed.withOpacity(0.5), width: 2),
                  ),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: DesignTokens.dividerOn(isDark),
                    backgroundImage: NetworkImage(displayUrl),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.article.authorName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          fontSize: 16,
                          color: DesignTokens.textPrimaryOn(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formattedDate,
                        style: TextStyle(
                          color: DesignTokens.textSecondaryOn(isDark), 
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionBar(bool isDark) {
    return FadeInUp(
      duration: const Duration(milliseconds: 800),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.primaryDark : Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              )
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Like Button with Bounce
              GestureDetector(
                onTap: _handleLike,
                child: Row(
                  children: [
                    if (_hasLiked)
                      BounceIn(
                        duration: const Duration(milliseconds: 500),
                        child: const Icon(Icons.favorite, color: AppColors.primaryRed, size: 26),
                      )
                    else
                      Icon(Icons.favorite_border, color: DesignTokens.textSecondaryOn(isDark), size: 26),
                    const SizedBox(width: 8),
                    Text(
                      '$_localLikes',
                      style: TextStyle(
                        color: _hasLiked ? AppColors.primaryRed : DesignTokens.textSecondaryOn(isDark),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: DesignTokens.dividerOn(isDark),
              ),
              
              // Comment Button
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => Padding(
                      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1), // max height margin
                      child: ArticleCommentsSheet(articleId: widget.article.id),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded, color: DesignTokens.textSecondaryOn(isDark), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'टिप्पणी',
                      style: TextStyle(
                        color: DesignTokens.textSecondaryOn(isDark),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Divider
              Container(
                height: 24,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                color: DesignTokens.dividerOn(isDark),
              ),
              
              // Share Button
              GestureDetector(
                onTap: () {
                   Share.share('विवेचना-ओज पर यह लेख पढ़ें: ${widget.article.title} - ${widget.article.authorName} द्वारा\n\n#VivechanaOJ #SahityaJagat');
                },
                child: Icon(Icons.share_rounded, color: DesignTokens.textSecondaryOn(isDark), size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: DesignTokens.scaffoldOn(isDark),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: DesignTokens.dividerOn(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'लेख हटाएं',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: DesignTokens.textPrimaryOn(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'क्या आप वाकई इस लेख को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: DesignTokens.textSecondaryOn(isDark),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: DesignTokens.dividerOn(isDark)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'रद्द करें',
                      style: TextStyle(color: DesignTokens.textPrimaryOn(isDark), fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'हटाएं',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (confirm == true) {
      final success = await _articleService.deleteArticle(
        widget.article.id, 
        coverImageUrl: widget.article.coverImageUrl,
        notifyAuthorId: _isAdmin ? widget.article.authorId : null,
        articleTitle: _isAdmin ? widget.article.title : null,
      );
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('लेख सफलतापूर्वक हटा दिया गया।', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true); // Pop out to feed or profile, return true to refresh
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('लेख हटाने में विफल।', style: TextStyle(color: Colors.white)),
              backgroundColor: Colors.redAccent,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

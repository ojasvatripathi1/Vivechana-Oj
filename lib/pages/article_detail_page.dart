import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import '../models/article.dart';
import '../services/content_extraction_service.dart';
import '../services/article_service.dart';
import '../services/news_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';

class ArticleDetailPage extends StatefulWidget {
  final Article article;
  final String? heroTag;
  const ArticleDetailPage({super.key, required this.article, this.heroTag});

  @override
  State<ArticleDetailPage> createState() => _ArticleDetailPageState();
}

class _ArticleDetailPageState extends State<ArticleDetailPage> {
  final ScrollController _scrollController = ScrollController();
  final ContentExtractionService _extractionService = ContentExtractionService();
  final ArticleService _articleService = ArticleService();
  final NewsService _newsService = NewsService();
  
  bool _showStickyBar = false;
  bool _isBookmarked = false;
  bool _isLoadingContent = true;
  bool _isSaving = false;
  bool _hasLiked = false;
  bool _isLiking = false;
  int _localLikes = 0;
  List<Article> _relatedArticles = [];
  String? _fullContent;
  String? _extractedImage;

  @override
  void initState() {
    super.initState();
    _fetchFullContent();
    _checkIfBookmarked();
    _checkIfLiked();
    _loadLikeCount();
    _recordReadingHistory();
    _loadRelatedArticles();
    _scrollController.addListener(() {
      final double progress = _scrollController.offset / 500;
      if (progress > 0.25 && !_showStickyBar) {
        setState(() => _showStickyBar = true);
      } else if (progress <= 0.25 && _showStickyBar) {
        setState(() => _showStickyBar = false);
      }
    });
  }

  Future<void> _loadRelatedArticles() async {
    try {
      final category = widget.article.category.isNotEmpty ? widget.article.category : null;
      final response = await _newsService.fetchNews(category: category);
      final List<Article> articles = response['articles'] ?? [];
      // Remove the current article and take up to 5
      final related = articles
          .where((a) => a.id != widget.article.id && a.title != widget.article.title)
          .take(5)
          .toList();
      if (mounted) {
        setState(() => _relatedArticles = related);
      }
    } catch (e) {
      debugPrint('Error loading related articles: $e');
    }
  }

  Future<void> _recordReadingHistory() async {
    try {
      AppLogger.action('article_opened', parameters: {
        'article_id': widget.article.id,
        'title': widget.article.title,
        'category': widget.article.category,
      });

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reading_history')
          .doc(widget.article.id);
          
      await docRef.set({
        'title': widget.article.title,
        'author': widget.article.author.isEmpty ? 'अज्ञात लेखक' : widget.article.author,
        'category': widget.article.category.isEmpty ? 'सामान्य' : widget.article.category,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving reading history: $e');
    }
  }

  Future<void> _checkIfLiked() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final doc = await FirebaseFirestore.instance
          .collection('news_articles')
          .doc(widget.article.id)
          .collection('likes')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() => _hasLiked = true);
      }
    } catch (e) {
      debugPrint('Error checking news like status: $e');
    }
  }

  Future<void> _loadLikeCount() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('news_articles')
          .doc(widget.article.id)
          .collection('likes')
          .get();
      if (mounted) {
        setState(() => _localLikes = snapshot.docs.length);
      }
    } catch (e) {
      debugPrint('Error loading like count: $e');
    }
  }

  // ── news_articles document guard ────────────────────────────────────
  //
  // The news_articles/{id} parent document must exist before we can write
  // subcollections (likes, comments) into it. Without this, concurrent writes
  // from multiple users opening the same article simultaneously would each try
  // to CREATE the parent document, causing write conflicts.
  //
  // SetOptions(merge: true) is IDEMPOTENT — safe to call from many clients
  // at the same time. If the document already exists the data is silently
  // merged (no overwrite of existing fields).
  Future<void> _ensureNewsArticleDoc() async {
    try {
      await FirebaseFirestore.instance
          .collection('news_articles')
          .doc(widget.article.id)
          .set(
        {
          'id':       widget.article.id,
          'title':    widget.article.title,
          'url':      widget.article.url,
          'category': widget.article.category,
          // Only set createdAt if the doc is new — merge:true skips existing fields
          // but serverTimestamp is always applied. Use a sentinel to avoid overwriting.
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      // Non-fatal — the like/comment write below may still succeed if
      // the parent doc was created by a concurrent request.
      debugPrint('[ArticleDetailPage] _ensureNewsArticleDoc error (non-fatal): $e');
    }
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('पसंद करने के लिए लॉगिन करें।')),
      );
      return;
    }

    setState(() => _isLiking = true);

    if (_hasLiked) {
      setState(() {
        _hasLiked = false;
        _localLikes = (_localLikes > 0) ? _localLikes - 1 : 0;
      });
      try {
        await FirebaseFirestore.instance
            .collection('news_articles')
            .doc(widget.article.id)
            .collection('likes')
            .doc(user.uid)
            .delete();
      } catch (e) {
        debugPrint('Error removing news like: $e');
        setState(() {
          _hasLiked = true;
          _localLikes++;
        });
      }
    } else {
      setState(() {
        _hasLiked = true;
        _localLikes++;
      });
      try {
        // Ensure the parent news_articles document exists before writing the
        // subcollection. Uses merge:true so concurrent writes are idempotent.
        await _ensureNewsArticleDoc();
        await FirebaseFirestore.instance
            .collection('news_articles')
            .doc(widget.article.id)
            .collection('likes')
            .doc(user.uid)
            // set() with no merge option is safe here because the document ID
            // is the user's UID — only one device per user can write this doc.
            .set({'timestamp': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('Error saving news like: $e');
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

  Future<void> _checkIfBookmarked() async {
    try {
      final isBookmarked = await _articleService.isArticleSaved(widget.article.id);
      if (mounted) {
        setState(() => _isBookmarked = isBookmarked);
      }
    } catch (e) {
      debugPrint('Error checking bookmark status: $e');
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    try {
      if (_isBookmarked) {
        await _articleService.removeArticle(widget.article.id);
      } else {
        await _articleService.saveArticle(widget.article);
      }
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBookmarked ? 'लेख सेव किया गया' : 'लेख हटाया गया'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('त्रुटि: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _fetchFullContent() async {
    if (widget.article.url.isEmpty) {
      setState(() => _isLoadingContent = false);
      return;
    }

    try {
      final extractionResult = await _extractionService.extractFullContent(widget.article.url);
      if (mounted) {
        setState(() {
          if (extractionResult != null) {
             _fullContent = extractionResult['content'];
             if (extractionResult['image'] != null && extractionResult['image']!.isNotEmpty) {
                // Determine if we should replace the image.
                // It's usually better to trust the site's og:image over a generic fallback
                _extractedImage = extractionResult['image'];
             }
          }
          _isLoadingContent = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingContent = false);
    }
  }



  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1️⃣ Collapsible SliverAppBar
              _buildSliverAppBar(context, isDark),

              SliverList(
                delegate: SliverChildListDelegate([
                  // 3️⃣ लेख सामग्री क्षेत्र
                  _buildArticleContent(isDark),

                  // 5️⃣ लेखक जानकारी कार्ड
                  _buildAuthorCard(isDark),

                  // 6️⃣ प्रीमियम CTA (यदि लागू)
                  if (widget.article.isPremium) _buildPremiumCTA(),

                  // 7️⃣ संबंधित लेख
                  _buildRelatedArticles(isDark),

                  const SizedBox(height: 100), // Space for bottom bar
                ]),
              ),
            ],
          ),

          // 4️⃣ फ़्लोटिंग क्विक एक्शन बटन
          _buildFloatingActions(),

          // 9️⃣ स्टिकी बॉटम एक्शन बार
          if (_showStickyBar) _buildStickyBottomBar(isDark),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, bool isDark) {
    return SliverAppBar(
      expandedHeight: 260.0,
      collapsedHeight: 70.0,
      pinned: true,
      backgroundColor: DesignTokens.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: Colors.white,
          ),
          onPressed: _isSaving ? null : _toggleBookmark,
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {
            Share.share('${widget.article.title}\n\nयह खबर विवेचना-ओज ऐप पर पढ़ें:\nhttps://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj\n\n#VivechanaOJ #SahityaJagat');
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
          // 2️⃣ फीचर्ड इमेज सेक्शन
            Hero(
              tag: widget.heroTag ?? 'article_image_${widget.article.id}_${DateTime.now().microsecondsSinceEpoch}',
              child: Image.network(
                _extractedImage ?? widget.article.image,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: isDark ? DesignTokens.surface : Colors.grey[200],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image, size: 50, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text('छवि उपलब्ध नहीं है', style: TextStyle(color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    DesignTokens.primary.withOpacity(0.7),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: DesignTokens.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      widget.article.category,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FadeInUp(
                    child: Text(
                      widget.article.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${widget.article.author}  •  ${widget.article.date}',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      const Spacer(),
                      const Icon(Icons.access_time, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        widget.article.readTime,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArticleContent(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: DesignTokens.scaffoldOn(isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.article.subtitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: DesignTokens.textSecondaryOn(isDark),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          if (_isLoadingContent)
            _buildContentSkeleton(isDark)
          else if (_fullContent != null && _fullContent!.length > 50)
            ..._fullContent!.split('\n\n').map((para) => Padding(
              padding: const EdgeInsets.only(bottom: 18.0),
              child: FadeIn(
                child: Text(
                  para,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.7,
                    color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                  ),
                ),
              ),
            ))
          else
            ...widget.article.content.map((para) {
              if (para.startsWith('QUOTE:')) {
                return _buildQuote(para.replaceFirst('QUOTE:', ''), isDark);
              } else if (para.startsWith('HIGHLIGHT:')) {
                return _buildHighlight(para.replaceFirst('HIGHLIGHT:', ''), isDark);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 18.0),
                child: FadeIn(
                  child: Text(
                    para,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                    ),
                  ),
                ),
              );
            }),
          
        ],
      ),
    );
  }

  Widget _buildContentSkeleton(bool isDark) {
    return Column(
      children: List.generate(5, (index) => Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: double.infinity, height: 14, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 8),
            Container(width: double.infinity, height: 14, color: isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 8),
            Container(width: MediaQuery.of(context).size.width * 0.6, height: 14, color: isDark ? Colors.white10 : Colors.grey[200]),
          ],
        ),
      )),
    );
  }

  Widget _buildQuote(String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.fromLTRB(20, 10, 10, 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
        border: const Border(left: BorderSide(color: DesignTokens.error, width: 4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 17,
          fontStyle: FontStyle.italic,
          height: 1.5,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildHighlight(String text, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      color: DesignTokens.accent.withOpacity(0.2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildAuthorCard(bool isDark) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.appbarGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: DesignTokens.accent, width: 2),
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage(widget.article.authorImage),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.article.author,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.article.authorBio,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumCTA() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            DesignTokens.primary,
            DesignTokens.accent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text(
            'पूरा लेख पढ़ने के लिए मैगज़ीन खरीदें',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('माफ़ी चाहते हैं, यह सुविधा अभी उपलब्ध नहीं है')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.accent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text('₹20 में पढ़ें'),
          ),
        ],
      ),
    );
  }

  Widget _buildRelatedArticles(bool isDark) {
    if (_relatedArticles.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
          child: Text(
            'संबंधित लेख',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DesignTokens.primaryLight),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _relatedArticles.length,
            itemBuilder: (context, index) {
              final related = _relatedArticles[index];
              final heroTag = 'related_${related.id}_$index';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArticleDetailPage(article: related, heroTag: heroTag),
                  ),
                ),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? DesignTokens.surface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Hero(
                          tag: heroTag,
                          child: Image.network(
                            related.image,
                            height: 110,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 110,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              related.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: DesignTokens.textPrimaryOn(isDark),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              related.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: DesignTokens.textSecondaryOn(isDark)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActions() {
    return Positioned(
      right: 20,
      bottom: 100,
      child: Column(
        children: [
          _buildFloatingButton(
            _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            _isSaving ? null : _toggleBookmark,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingButton(IconData icon, VoidCallback? onTap) {
    return ZoomIn(
      child: FloatingActionButton.small(
        heroTag: 'article_fab_${icon.hashCode}',
        onPressed: onTap,
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        child: Icon(icon),
      ),
    );
  }

  Widget _buildStickyBottomBar(bool isDark) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SlideInUp(
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          decoration: BoxDecoration(
            color: isDark ? DesignTokens.primary : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStickyIcon(
                _hasLiked ? Icons.favorite : Icons.favorite_border,
                '$_localLikes लाइक',
                _toggleLike,
                isActive: _hasLiked,
              ),
              _buildStickyIcon(Icons.chat_bubble_outline, 'कमेंट', () => _showComments(context)),
              _buildStickyIcon(
                _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                'सेव',
                _isSaving ? null : _toggleBookmark,
                isActive: _isBookmarked,
              ),
              _buildStickyIcon(Icons.share_outlined, 'शेयर', () {
                Share.share('${widget.article.title}\n\nयह खबर विवेचना-ओज ऐप पर पढ़ें:\nhttps://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj\n\n#VivechanaOJ #SahityaJagat');
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyIcon(IconData icon, String label, VoidCallback? onTap, {bool isActive = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24, color: isActive ? AppColors.primaryRed : AppColors.primaryLight),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: isActive ? AppColors.primaryRed : Colors.grey)),
        ],
      ),
    );
  }

  void _showComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NewsCommentsSheet(articleId: widget.article.id),
    );
  }
}

// ─── News Comments Sheet (Firestore-backed) ─────────────────────────────────
class _NewsCommentsSheet extends StatefulWidget {
  final String articleId;
  const _NewsCommentsSheet({required this.articleId});

  @override
  State<_NewsCommentsSheet> createState() => _NewsCommentsSheetState();
}

class _NewsCommentsSheetState extends State<_NewsCommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
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

    String authorName = user.displayName ?? 'उपयोगकर्ता';
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        authorName = userDoc.data()!['fullName'] ?? authorName;
      }
    } catch (e) {
      debugPrint('Could not fetch user doc for name: $e');
    }

    try {
      // Ensure the parent news_articles/{id} document exists before writing
      // the comments subcollection. Uses merge:true — idempotent under concurrency.
      await FirebaseFirestore.instance
          .collection('news_articles')
          .doc(widget.articleId)
          .set(
        {'id': widget.articleId, 'createdAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance
          .collection('news_articles')
          .doc(widget.articleId)
          .collection('comments')
          .add({
        'text': text,
        'authorId': user.uid,
        'authorName': authorName,
        'authorImageUrl': user.photoURL,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        _commentController.clear();
        FocusScope.of(context).unfocus();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('टिप्पणी पोस्ट नहीं की जा सकी।')),
        );
      }
    }

    if (mounted) setState(() => _isSubmitting = false);
  }

  Future<void> _deleteComment(String commentId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('टिप्पणी हटाएं?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text('क्या आप वाकई इस टिप्पणी को हटाना चाहते हैं?'),
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
      try {
        await FirebaseFirestore.instance
            .collection('news_articles')
            .doc(widget.articleId)
            .collection('comments')
            .doc(commentId)
            .delete();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('टिप्पणी हटाने में त्रुटि हुई।'), backgroundColor: Colors.red),
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: DesignTokens.scaffoldOn(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(color: DesignTokens.dividerOn(isDark), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Text('टिप्पणियां', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DesignTokens.textPrimaryOn(isDark))),
          Divider(color: DesignTokens.dividerOn(isDark), height: 24),

          // Comments list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('news_articles')
                  .doc(widget.articleId)
                  .collection('comments')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('अभी तक कोई टिप्पणी नहीं है। पहली टिप्पणी करें!',
                          style: TextStyle(color: DesignTokens.textSecondaryOn(isDark)), textAlign: TextAlign.center),
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
                              color: isDark ? const Color(0xFF1E1E2E) : Colors.grey.shade100,
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
                                      child: Text(authorName,
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: DesignTokens.textPrimaryOn(isDark)),
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(timeAgoStr, style: TextStyle(fontSize: 11, color: DesignTokens.textSecondaryOn(isDark))),
                                        if (isOwnComment) ...[
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: () => _deleteComment(commentId),
                                            child: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red.shade400),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(text, style: TextStyle(fontSize: 14, height: 1.4, color: DesignTokens.textPrimaryOn(isDark).withOpacity(0.9))),
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

          // Comment input
          Container(
            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
            decoration: BoxDecoration(
              color: DesignTokens.scaffoldOn(isDark),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)],
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
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
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
                        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
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

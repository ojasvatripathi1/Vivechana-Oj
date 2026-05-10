import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/writer_article.dart';
import '../services/writer_article_service.dart';
import 'writer_article_detail_page.dart';

class WriterProfilePage extends StatefulWidget {
  final Map<String, String> writer;

  const WriterProfilePage({super.key, required this.writer});

  @override
  State<WriterProfilePage> createState() => _WriterProfilePageState();
}

class _WriterProfilePageState extends State<WriterProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isBioExpanded = false;

  final WriterArticleService _articleService = WriterArticleService();
  late Future<List<WriterArticle>> _articlesFuture;

  final List<String> _filters = ['सभी', 'लेख', 'कहानी', 'कविता', 'ग़ज़ल', 'प्रीमियम'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {}); // Re-build list based on filter
      }
    });
    
    _refreshArticles();
  }

  void _refreshArticles() {
    final authorId = widget.writer['uid'];
    if (authorId != null && authorId.isNotEmpty) {
       _articlesFuture = _articleService.getArticlesByAuthor(authorId, onlyApproved: true);
    } else {
       // Fallback if uid is somehow missing, though it shouldn't be with our updates
       _articlesFuture = Future.value([]);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: RefreshIndicator(
        color: const Color(0xFFE6501B),
        onRefresh: () async {
          setState(() {
            _refreshArticles();
          });
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(), // Important for RefreshIndicator
          slivers: [
            // 1️⃣ Collapsible Premium SliverAppBar
            _buildSliverAppBar(isDark),

          // 2️⃣ Writer Bio Section
          SliverToBoxAdapter(child: _buildBioSection(isDark)),

          // 3️⃣ Content Filter Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterHeaderDelegate(_tabController, _filters, isDark),
          ),

          // 4️⃣ Published Content List
          _buildContentFuture(isDark),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    ),
  );
}

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 280.0,
      collapsedHeight: 80.0,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF280905),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share, color: Colors.white),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('लेखक को साझा करने की सुविधा शीघ्र ही आएगी')),
            );
          },
        ),
        if (FirebaseAuth.instance.currentUser?.uid != widget.writer['uid'])
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              final parentContext = context;
              showModalBottomSheet(
              context: parentContext,
              builder: (sheetContext) => Container(
                color: const Color(0xFF1A1A1A),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.report, color: Colors.white),
                      title: const Text('रिपोर्ट करें', style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(sheetContext);
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(parentContext).showSnackBar(
                            const SnackBar(content: Text('रिपोर्ट करने के लिए पहले लॉगिन करें।')),
                          );
                          return;
                        }
                        
                        try {
                          await FirebaseFirestore.instance.collection('user_reports').add({
                            'reporterId': currentUser.uid,
                            'reportedUserId': widget.writer['uid'],
                            'reportedUserName': widget.writer['name'],
                            'timestamp': FieldValue.serverTimestamp(),
                            'status': 'pending',
                          });
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('आपकी रिपोर्ट सबमिट हो गई। हम इसकी जांच करेंगे।')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(content: Text('रिपोर्ट सबमिट करने में विफल।'), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.block, color: Colors.white),
                      title: const Text('ब्लॉक करें', style: TextStyle(color: Colors.white)),
                      onTap: () async {
                        Navigator.pop(context);
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ब्लॉक करने के लिए पहले लॉगिन करें।')),
                          );
                          return;
                        }

                        // Confirmation Dialog
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('${widget.writer['name']} को ब्लॉक करें?'),
                            content: const Text('क्या आप वाकई इस लेखक को ब्लॉक करना चाहते हैं? आप इनकी रचनाएं नहीं देख पाएंगे।'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('रद्द करें', style: TextStyle(color: Colors.black54)),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('ब्लॉक करें', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            // Update currentUser document's blockedUsers array
                            await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
                              'blockedUsers': FieldValue.arrayUnion([widget.writer['uid']])
                            });
                            
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('लेखक को ब्लॉक कर दिया गया।')),
                              );
                              // Pop back to previous page since the artist is now blocked
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('नेटवर्क त्रुटि: ब्लॉक नहीं किया जा सका।'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final double percentage = ((constraints.maxHeight - 80) / (280 - 80)).clamp(0.0, 1.0);
            return Opacity(
              opacity: (1.0 - percentage * 5).clamp(0.0, 1.0),
              child: percentage < 0.2 
                ? Text(
                    widget.writer['name']!,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  )
                : const SizedBox.shrink(),
            );
          }
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF280905), Color(0xFF740A03)],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Subtle texture or pattern could be added here
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Hero(
                    tag: 'writer_image_${widget.writer['name']}',
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primaryRed, width: 3),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(widget.writer['image']!),
                        onBackgroundImageError: (exception, stackTrace) {}, // Ignore errors and just show empty circle if it fails completely
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FadeIn(
                    duration: const Duration(milliseconds: 600),
                    child: Text(
                      widget.writer['name']!,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeInUp(
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      widget.writer['gender'] == 'महिला' ? 'लेखिका' : 'लेखक',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBioSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'लेखक के बारे में',
            style: TextStyle(color: Color(0xFF740A03), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          AnimatedCrossFade(
            firstChild: Text(
              (widget.writer['bio'] != null && widget.writer['bio']!.trim().isNotEmpty)
                  ? widget.writer['bio']!
                  : 'विवेचना-ओज के एक सम्मानित रचनाकार, जिनकी रचनाएँ पाठकों को गहराई से प्रभावित करती हैं।',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.6),
            ),
            secondChild: Text(
              (widget.writer['bio'] != null && widget.writer['bio']!.trim().isNotEmpty)
                  ? widget.writer['bio']!
                  : 'विवेचना-ओज के एक सम्मानित रचनाकार, जिनकी रचनाएँ पाठकों को गहराई से प्रभावित करती हैं।',
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14, height: 1.6),
            ),
            crossFadeState: _isBioExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _isBioExpanded = !_isBioExpanded),
            child: Text(
              _isBioExpanded ? 'कम दिखाएं' : 'और पढ़ें',
              style: const TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentFuture(bool isDark) {
    return FutureBuilder<List<WriterArticle>>(
      future: _articlesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
            ),
          );
        }

        if (snapshot.hasError) {
           return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Center(child: Text('डेटा लोड करने में त्रुटि: ${snapshot.error}')),
            ),
          );
        }

        final articles = snapshot.data ?? [];
        
        final selectedFilter = _filters[_tabController.index];
        List<WriterArticle> filteredArticles = [];

        if (selectedFilter == 'सभी') {
          // Deep copy to sort locally
          filteredArticles = List.from(articles);
          // Sort primary by Category, secondary by Date
          filteredArticles.sort((a, b) {
            int catCompare = a.category.compareTo(b.category);
            if (catCompare != 0) return catCompare;
            return b.createdAt.compareTo(a.createdAt);
          });
        } else if (selectedFilter == 'लेख') {
          filteredArticles = articles.where((a) => a.category == 'लेख' || a.category == 'संस्मरण').toList();
        } else {
          filteredArticles = articles.where((a) => a.category == selectedFilter).toList();
        }

        if (filteredArticles.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(isDark, selectedFilter),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              return FadeInUp(
                delay: Duration(milliseconds: 50 * index),
                child: _buildArticleCard(filteredArticles[index], isDark),
              );
            },
            childCount: filteredArticles.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark, String filter) {
    String message = 'इस लेखक ने अभी तक कुछ प्रकाशित नहीं किया है।';
    if (filter != 'सभी') {
      message = 'इस श्रेणी (Category) में कोई लेख नहीं है।';
    }

    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_stories_outlined, size: 80, color: const Color(0xFFC3110C).withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white54 : Colors.black54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleCard(WriterArticle article, bool isDark) {
    return InkWell(
      onTap: () async {
        // Capture returned updated article (e.g. if likes changed)
        final updatedArticle = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => WriterArticleDetailPage(article: article),
          ),
        );
        
        if (updatedArticle != null && updatedArticle is WriterArticle) {
          if (mounted) {
            setState(() {
               _refreshArticles();
            });
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (article.coverImageUrl != null && article.coverImageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(article.coverImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFE6501B), borderRadius: BorderRadius.circular(4)),
                        child: Text(article.category, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                      if (article.status == 'pending') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)),
                          child: const Text('समीक्षा के लिए (Pending)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                      if (article.status == 'rejected') ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                          child: const Text('अस्वीकृत (Rejected)', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(article.title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(article.plainTextContent.length > 100 ? '${article.plainTextContent.substring(0, 100)}...' : article.plainTextContent, 
                      maxLines: 2, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${article.readTimeMinutes} मिनट पढ़ें', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      const Spacer(),
                      const Icon(Icons.visibility_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${article.views}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Icon(Icons.thumb_up_alt_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${article.likes}', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      if (FirebaseAuth.instance.currentUser?.uid == article.authorId) ...[
                        const Spacer(),
                        InkWell(
                          onTap: () => _confirmDelete(article),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          ),
                        ),
                      ],
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

  Future<void> _confirmDelete(WriterArticle article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('लेख हटाएं'),
        content: const Text('क्या आप वाकई इस लेख को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('हटाएं', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _articleService.deleteArticle(article.id, coverImageUrl: article.coverImageUrl);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लेख सफलतापूर्वक हटा दिया गया।'), backgroundColor: Colors.green),
          );
          setState(() {
            _refreshArticles();
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लेख हटाने में विफल।'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}

class _FilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController _tabController;
  final List<String> _filters;
  final bool _isDark;

  _FilterHeaderDelegate(this._tabController, this._filters, this._isDark);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        tabs: _filters.map((filter) {
          return AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              final isSelected = _tabController.index == _filters.indexOf(filter);
              return Tab(
                height: 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFC3110C) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? Colors.white54 : const Color(0xFF740A03)),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : const Color(0xFF740A03)),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        }).toList(),
      ),
    );
  }

  @override
  double get maxExtent => 52.0;
  @override
  double get minExtent => 52.0;
  @override
  bool shouldRebuild(covariant _FilterHeaderDelegate oldDelegate) {
    return false;
  }
}

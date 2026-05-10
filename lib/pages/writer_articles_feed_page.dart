import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:shimmer/shimmer.dart';

import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import '../models/writer_article.dart';
import '../services/writer_article_service.dart';
import '../utils/app_routes.dart';
import 'create_writer_article_page.dart';
import 'writer_article_detail_page.dart';
import 'writer_profile_page.dart';

class WriterArticlesFeedPage extends StatefulWidget {
  const WriterArticlesFeedPage({super.key});

  @override
  State<WriterArticlesFeedPage> createState() => _WriterArticlesFeedPageState();
}

class _WriterArticlesFeedPageState extends State<WriterArticlesFeedPage> with SingleTickerProviderStateMixin {
  final WriterArticleService _articleService = WriterArticleService();
  bool _isWriter = false;
  bool _isAdmin = false;
  
  late TabController _tabController;
  final List<String> _categories = ['सभी', 'लेख', 'कहानी', 'कविता', 'ग़ज़ल'];
  
  
  List<WriterArticle> _articles = [];
  bool _isLoading = true;
  
  // Cache to store fetched profile images for authors
  final Map<String, String> _authorImageCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    
    // Setup timeago in Hindi if possible
    timeago.setLocaleMessages('hi', timeago.HiMessages());
    
    _checkWriterStatus();
    _fetchArticles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    _fetchArticles();
  }

  Future<void> _checkWriterStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Check Admin Status natively from the Users Collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        bool isAdmin = false;

        if (userDoc.exists) {
          final data = userDoc.data();
          isAdmin = data?['isAdmin'] == true || user.email == 'vivechanaoaj@gmail.com';
        }

        // 2. Strict Check for Writer Registration Approved Status
        bool isApprovedWriter = false;
        final writerRegs = await FirebaseFirestore.instance
            .collection('writer_registrations')
            .where('uid', isEqualTo: user.uid)
            .get();

        if (writerRegs.docs.isNotEmpty) {
          final regData = writerRegs.docs.first.data();
          if (regData['status'] == 'approved') {
            isApprovedWriter = true;
          }
        }

        // 3. Set global flags
        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
            _isWriter = isApprovedWriter || isAdmin;
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking strict writer status: $e');
    }
  }

  Future<void> _fetchArticles() async {
    setState(() => _isLoading = true);
    final category = _categories[_tabController.index];
    
    try {
      final articles = await _articleService.getFeedArticles(
        category: category == 'सभी' ? null : category,
      );
      if (mounted) {
        setState(() {
          _articles = articles;
          _isLoading = false;
        });
        _fetchMissingAuthorImages(articles);
      }
    } catch (e) {
      debugPrint('Error fetching articles: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMissingAuthorImages(List<WriterArticle> articles) async {
    final Set<String> authorsToFetch = {};
    for (var article in articles) {
      if (article.authorImageUrl == null || article.authorImageUrl!.contains('ui-avatars.com')) {
        if (!_authorImageCache.containsKey(article.authorId)) {
          authorsToFetch.add(article.authorId);
        }
      }
    }

    for (String authorId in authorsToFetch) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('writer_registrations')
            .where('uid', isEqualTo: authorId)
            .limit(1)
            .get();
        
        if (doc.docs.isNotEmpty) {
          final data = doc.docs.first.data();
          if (data['profileImageUrl'] != null && data['profileImageUrl'].toString().isNotEmpty) {
            if (mounted) {
              setState(() {
                _authorImageCache[authorId] = data['profileImageUrl'];
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching author image for $authorId: $e');
      }
    }
  }

  Future<void> _navigateToWriterProfile(WriterArticle article) async {
    final docIdStr = article.authorId;
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
        writerMap = {
          'name': article.authorName,
          'designation': 'लेखक',
          'quote': 'विवेचना-ओज के एक मूल्यवान लेखक।',
          'bio': 'विवेचना-ओज के एक सम्मानित रचनाकार, जिनकी रचनाएँ पाठकों को गहराई से प्रभावित करती हैं।',
          'gender': '',
          'image': article.authorImageUrl ?? 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(article.authorName)}&background=9B0B1E&color=fff&size=128&bold=true',
          'uid': docIdStr,
        };
      }

      Navigator.push(context, MaterialPageRoute(
        builder: (context) => WriterProfilePage(writer: writerMap),
      ));
    } catch (e) {
      debugPrint('Error navigating to profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark; // Assuming light mode preference for now based on previous code
    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              pinned: true,
              elevation: 0,
              scrolledUnderElevation: 0,
              backgroundColor: DesignTokens.scaffoldOn(isDark).withOpacity(0.95),
              titleSpacing: 16,
              centerTitle: false,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryRed, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/vivechana-oj-logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'साहित्य जगत',
                        style: GoogleFonts.notoSansDevanagari(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: DesignTokens.textPrimaryOn(isDark),
                          letterSpacing: 0.3,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 13,
                            color: AppColors.primaryRed,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'रचनाएँ व कहानियाँ',
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryRed,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              iconTheme: IconThemeData(color: DesignTokens.textPrimaryOn(isDark)),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(76),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.center,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      color: AppColors.primaryRed,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryRed.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: DesignTokens.textSecondaryOn(isDark),
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                    padding: const EdgeInsets.all(4),
                    tabs: _categories.map((c) => Tab(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(c),
                      ),
                    )).toList(),
                  ),
                ),
              ),
            ),
          ];
        },
        body: RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: _fetchArticles,
          child: _isLoading
              ? _buildShimmerLoading(isDark)
              : _articles.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 100),
                      itemCount: _articles.length,
                      itemBuilder: (context, index) {
                        return FadeInUp(
                          delay: Duration(milliseconds: 50 * index),
                          duration: const Duration(milliseconds: 500),
                          child: _buildModernArticleCard(_articles[index], isDark),
                        );
                      },
                    ),
        ),
      ),
      floatingActionButton: _isWriter
          ? FadeInRight(
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    AppRoutes.slideUp(const CreateWriterArticlePage()),
                  );
                  if (result == true) {
                    _fetchArticles(); // Refresh after posting
                  }
                },
                backgroundColor: AppColors.primaryRed,
                elevation: 4,
                icon: const Icon(Icons.edit_document, color: Colors.white),
                label: const Text('नई रचना', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            )
          : null,
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.white;
    final blockColor = isDark ? Colors.grey.shade800 : const Color(0xFFE0E0E0);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.transparent),
            ),
            child: Column(
              children: [
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 14, width: 60, color: blockColor),
                      const SizedBox(height: 12),
                      Container(height: 20, width: double.infinity, color: blockColor),
                      const SizedBox(height: 8),
                      Container(height: 20, width: 200, color: blockColor),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(height: 28, width: 28, decoration: BoxDecoration(shape: BoxShape.circle, color: blockColor)),
                          const SizedBox(width: 8),
                          Container(height: 14, width: 100, color: blockColor),
                        ],
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

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: FadeIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_outlined, size: 60, color: AppColors.primaryRed.withOpacity(0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              'अभी कोई रचना नहीं है',
              style: TextStyle(color: DesignTokens.textPrimaryOn(isDark), fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'इस श्रेणी में अभी तक कुछ प्रकाशित नहीं हुआ है।',
              style: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernArticleCard(WriterArticle article, bool isDark) {
    final String timeAgo = timeago.format(article.createdAt, locale: 'hi');
    
    final avatarUrl = _authorImageCache[article.authorId] ?? article.authorImageUrl;
    final displayUrl = (avatarUrl != null && avatarUrl.isNotEmpty)
        ? avatarUrl
        : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(article.authorName)}&background=9B0B1E&color=fff&size=128&bold=true';
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: DesignTokens.dividerOn(isDark).withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          highlightColor: AppColors.primaryRed.withOpacity(0.05),
          splashColor: AppColors.primaryRed.withOpacity(0.1),
          onTap: () async {
            final updatedArticle = await Navigator.push(
              context,
              AppRoutes.slideRight(WriterArticleDetailPage(article: article)),
            );
            
            // If the user deleted the article from within the detail page, it might return true
            if (updatedArticle == true) {
              _fetchArticles(); // Refresh if article was deleted
            } 
            // If it returns an updated WriterArticle (e.g. they liked it)
            else if (updatedArticle != null && updatedArticle is WriterArticle) {
              if (mounted) {
                setState(() {
                  final index = _articles.indexWhere((a) => a.id == updatedArticle.id);
                  if (index != -1) {
                    _articles[index] = updatedArticle;
                  }
                });
              }
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.coverImageUrl != null)
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      child: Image.network(
                        article.coverImageUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    // Gradient overlay at top for tags perfectly matching corner radius
                    Positioned(
                      top: 0, left: 0, right: 0,
                      child: Container(
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (article.coverImageUrl == null) ...[ // Category visible if no image
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          article.category,
                          style: const TextStyle(
                            color: AppColors.primaryRed,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.textPrimaryOn(isDark),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.plainTextContent,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.textSecondaryOn(isDark),
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _navigateToWriterProfile(article),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: NetworkImage(displayUrl),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.authorName,
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: DesignTokens.textPrimaryOn(isDark)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    timeAgo,
                                    style: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 11, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        _buildStatIcon(Icons.favorite, '${article.likes}', AppColors.primaryRed.withOpacity(0.8)),
                        const SizedBox(width: 12),
                        _buildStatIcon(Icons.visibility, '${article.views}', Colors.grey.shade500),
                        
                        if (FirebaseAuth.instance.currentUser?.uid == article.authorId || _isAdmin) ...[
                          const SizedBox(width: 12),
                          InkWell(
                            onTap: () => _confirmDelete(article),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
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
      ),
    );
  }

  Widget _buildStatIcon(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Future<void> _confirmDelete(WriterArticle article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('रचना हटाएं', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('क्या आप वाकई इस रचना को हटाना चाहते हैं? यह क्रिया पूर्ववत नहीं की जा सकती।', style: TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('हटाएं', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _articleService.deleteArticle(article.id, coverImageUrl: article.coverImageUrl);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(
               content: const Row(children: [Icon(Icons.check_circle, color: Colors.white), SizedBox(width: 10), Text('रचना सफलतापूर्वक हटा दी गई।')]),
               backgroundColor: Colors.green.shade600,
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
             ),
          );
          _fetchArticles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
               content: const Row(children: [Icon(Icons.error_outline, color: Colors.white), SizedBox(width: 10), Text('हटाने में विफल। कृपया पुनः प्रयास करें।')]),
               backgroundColor: Colors.red.shade600,
               behavior: SnackBarBehavior.floating,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
             ),
          );
        }
      }
    }
  }
}

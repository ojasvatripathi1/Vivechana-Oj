import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/news_service.dart';
import '../models/article.dart';
import '../utils/app_routes.dart';
import 'article_detail_page.dart';
import 'search_page.dart';
import 'local_news_page.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/magazine_service.dart';
import '../models/magazine_edition.dart';
import 'magazine_page.dart';

class NewsPage extends StatefulWidget {
  const NewsPage({super.key});

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> with TickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final NewsService _newsService = NewsService();
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  List<Article> _allNews = [];
  List<Article> _trendingNews = [];
  Map<String, List<Article>> _categoryWiseNews = {}; // Category-wise news map
  String? _nextPageToken;
  String _currentCategory = 'सभी';
  bool _showBackToTop = false;
  List<String> _trendingKeywords = [];
  Timer? _refreshTimer;
  DateTime? _lastFetchTime;
  
  final MagazineService _magazineService = MagazineService();
  StreamSubscription<List<MagazineEdition>>? _magazineSub;
  MagazineEdition? _latestEdition;
  bool _hasAccessToLatest = false;

  // ... (Local / City news removed)

  final List<String> _categories = [
    'सभी', 'भारत', 'राजनीति', 'अर्थव्यवस्था', 'खेल', 'टेक्नोलॉजी', 'विश्व', 'मनोरंजन'
  ];

  // ... (Cities list removed)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: _categories.length, vsync: this);
    _loadNews();
    _loadTrendingKeywords();
    _loadCategoryWiseNews();
    
    // Live update for latest magazine and checking access
    _magazineSub = _magazineService.getMagazinesStream().listen((magazines) {
      if (mounted && magazines.isNotEmpty) {
        final latest = magazines.first; // Stream is ordered by ID descending
        setState(() => _latestEdition = latest);
        
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _magazineService.getMembershipStatus(user.uid).then((status) {
            final hasAccess = status['isAdmin'] == true || status['type'] == 'annual' || 
                              (List<String>.from(status['paidEditions'] ?? [])).contains(latest.id);
            if (mounted) {
              setState(() => _hasAccessToLatest = hasAccess);
            }
          });
        }
      } else if (mounted && magazines.isEmpty) {
         setState(() => _latestEdition = null);
      }
    });

    // 🚨 TEMP DATA WIPE: Commented out to prevent perpetual wiping
    // _magazineService.debugWipeAllSubscriptions();
    
    
    // Auto-refresh every 2 minutes
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      if (mounted) {
        _loadNews(category: _currentCategory);
        if (_currentCategory == 'सभी') {
          _loadTrendingKeywords();
          _loadCategoryWiseNews();
        }
      }
    });
    
    _scrollController.addListener(() {
      if (!mounted) return;
      
      // Infinite scroll logic
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore && _nextPageToken != null) {
          _loadMoreNews();
        }
      }

      // Back to top button logic
      if (_scrollController.offset > 400 && !_showBackToTop) {
        setState(() => _showBackToTop = true);
      } else if (_scrollController.offset <= 400 && _showBackToTop) {
        setState(() => _showBackToTop = false);
      }
    });
  }

  // _checkLatestMagazineAccess was replaced by StreamSubscription in initState

  Future<void> _loadNews({String? category}) async {
    setState(() => _isLoading = true);
    try {
      final response = await _newsService.fetchNews(category: category);
      if (mounted) {
        setState(() {
          _allNews = response['articles'];
          _nextPageToken = response['nextPage'];
          // Set trending news (take first 3 if available)
          _trendingNews = _allNews.take(3).toList();
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Load news for all categories in parallel
  Future<void> _loadCategoryWiseNews() async {
    try {
      // Skip 'सभी' for category-wise load (it's already loaded in _allNews)
      final categoriesToLoad = _categories.where((c) => c != 'सभी').toList();
      final categoryNews = await _newsService.fetchAllCategoriesNews(categoriesToLoad);
      
      if (mounted) {
        setState(() {
          _categoryWiseNews = categoryNews;
        });
      }
    } catch (e) {
      print('Error loading category-wise news: $e');
    }
  }

  // _loadLocalNews removed

  // _showCitySelector removed

  Future<void> _loadTrendingKeywords() async {
    final keywords = await _newsService.fetchTrendingKeywords();
    if (mounted) {
      setState(() {
        _trendingKeywords = keywords;
      });
    }
  }

  Future<void> _loadMoreNews() async {
    setState(() => _isLoadingMore = true);
    try {
      final response = await _newsService.fetchNews(
        category: _currentCategory,
        page: _nextPageToken,
      );
      if (mounted) {
        setState(() {
          _allNews.addAll(response['articles']);
          _nextPageToken = response['nextPage'];
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _magazineSub?.cancel();
    _refreshTimer?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh if at least 2 minutes have passed since last fetch
      if (_lastFetchTime == null ||
          DateTime.now().difference(_lastFetchTime!).inMinutes >= 2) {
        _loadNews(category: _currentCategory);
        _loadTrendingKeywords();
        _loadCategoryWiseNews();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      body: RefreshIndicator(
        color: AppColors.accentOrange,
        onRefresh: () => _loadNews(category: _currentCategory),
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 1️⃣ Collapsible Gradient AppBar
            _buildAppBar(isDark),

            // 2️⃣ Breaking News Strip
            SliverToBoxAdapter(child: _buildBreakingNewsStrip()),

            // 3️⃣ Category Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _CategoryHeaderDelegate(
                _tabController, 
                _categories, 
                isDark,
                (category) {
                  setState(() => _currentCategory = category);
                  _loadNews(category: category);
                }
              ),
            ),

            // 4️⃣ Dynamic Trending Keywords
            if (_trendingKeywords.isNotEmpty)
              SliverToBoxAdapter(child: _buildTrendingKeywordsStrip(isDark)),

            if (_isLoading)
              SliverToBoxAdapter(child: _buildSkeletonLoader(isDark))
            else if (_allNews.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('कोई समाचार नहीं मिला।')),
              )
            else ...[
               // 5️⃣ Local / City News Section
                // _buildLocalNewsSection removed

               // 5️⃣ ट्रेंडिंग न्यूज़ सेक्शन (Only for "सभी" category)
               if (_currentCategory == 'सभी' && _trendingNews.isNotEmpty)
                  _buildTrendingSection(isDark),

               // 5️⃣ Category-wise News Sections (Only for "सभी" category)
               if (_currentCategory == 'सभी' && _categoryWiseNews.isNotEmpty)
                  ..._buildCategoryWiseSections(isDark),

               // 6️⃣ मुख्य न्यूज़ फ़ीड
               _buildNewsFeed(isDark),

               // Load more indicator
               if (_isLoadingMore)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accentOrange)),
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ],
        ),
      ),
      floatingActionButton: _showBackToTop
          ? FadeInUp(
              child: FloatingActionButton.small(
                heroTag: 'news_page_fab',
                onPressed: () => _scrollController.animateTo(0, 
                  duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
                backgroundColor: AppColors.primaryRed,
                child: const Icon(Icons.arrow_upward, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 130.0,
      collapsedHeight: 68.0,
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        child: FlexibleSpaceBar(
          centerTitle: false,
          titlePadding: const EdgeInsets.only(left: 16, bottom: 10),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentOrange, width: 2),
                ),
                child: ClipOval(
                  child: Image.asset('assets/vivechana-oj-logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'समाचार',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 21,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.newspaper_rounded, size: 12, color: AppColors.accentOrange),
                      const SizedBox(width: 3),
                      const Text(
                        'न्यूज़',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentOrange,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          background: Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ताज़ा खबरें • भारत और विश्व',
                  style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.explore, color: Colors.white),
          tooltip: 'लोकल न्यूज़',
          onPressed: () {
            Navigator.push(context, AppRoutes.slideUp(const LocalNewsPage()));
          },
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: Colors.white),
          onPressed: () {
            Navigator.push(context, AppRoutes.slideRight(const SearchPage()));
          },
        ),
        StreamBuilder<User?>(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: Colors.white24,
                backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                child: user?.photoURL == null
                    ? const Icon(Icons.person_outline, color: Colors.white, size: 20)
                    : null,
              ),
            );
          },
        ),
      ],
    );
  }

  // _buildLocationRow removed

  Widget _buildBreakingNewsStrip() {
    String breakingText = _allNews.isNotEmpty 
        ? _allNews.map((e) => e.title).join(' • ') 
        : 'ताज़ा समाचार लोड हो रहे हैं...';
    return Container(
      height: 42,
      width: double.infinity,
      color: AppColors.primaryRed,
      child: Row(
        children: [
          const SizedBox(width: 16),
          _PulseIcon(),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 42,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MarqueeText(text: 'ब्रेकिंग: $breakingText'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // _buildLocalNewsSection and _buildLocalNewsCard removed

  Widget _buildTrendingKeywordsStrip(bool isDark) {
    return Container(
      height: 50,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _trendingKeywords.length,
        itemBuilder: (context, index) {
          final keyword = _trendingKeywords[index];
          return FadeInRight(
            delay: Duration(milliseconds: index * 50),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SearchPage(preFillQuery: keyword)),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up, size: 14, color: AppColors.primaryRed),
                    const SizedBox(width: 6),
                    Text(
                      keyword,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTrendingSection(bool isDark) {
    if (_trendingNews.isEmpty) return const SizedBox.shrink();
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primaryLight, AppColors.accentOrange],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'ट्रेंडिंग अभी',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimaryOn(isDark),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 180,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _trendingNews.length,
              itemBuilder: (context, index) => _buildTrendingCard(_trendingNews[index], index, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingCard(Article article, int index, bool isDark) {
    final String heroTag = 'news_trending_${article.id}_$index';
    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article, heroTag: heroTag))),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(right: 16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Hero(
                tag: heroTag,
                child: Image.network(
                  article.image, 
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.primaryDark.withOpacity(0.8)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accentOrange, borderRadius: BorderRadius.circular(4)),
                    child: const Text('ट्रेंडिंग', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('${article.author} • ${article.date}', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCategoryWiseSections(bool isDark) {
    final sections = <Widget>[];
    
    _categoryWiseNews.forEach((category, articles) {
      if (articles.isEmpty) return;
      
      sections.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              children: [
                Container(
                  width: 4, height: 20,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.primaryLight, AppColors.accentOrange],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  category,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimaryOn(isDark),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      
      // Show first 3 articles in horizontal scrollable list that aren't already in trending
      final displayArticles = articles.where((a) => !_trendingNews.any((t) => t.id == a.id)).take(3).toList();
      if (displayArticles.isEmpty) return;

      sections.add(
        SliverToBoxAdapter(
          child: SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: displayArticles.length,
              itemBuilder: (context, index) {
                final article = displayArticles[index];
                final String heroTag = 'cat_${category}_${article.id}_$index';
                return GestureDetector(
                  onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article, heroTag: heroTag))),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Hero(
                            tag: heroTag,
                            child: Image.network(
                              article.image,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Colors.transparent, AppColors.primaryDark.withOpacity(0.7)],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  article.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  article.author,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    });
    
    return sections;
  }

  Widget _buildNewsFeed(bool isDark) {
    // If on "सभी" category, skip the trending ones in the main list
    final displayNews = _currentCategory == 'सभी' ? _allNews.skip(_trendingNews.length).toList() : _allNews;
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final article = displayNews[index];
          
          // 6️⃣ Premium Insight Banner after every 6 news
          if (index > 0 && index % 6 == 0) return _buildPremiumBanner();
          
          // Card type 2 - Feature News (every 5th item)
          if (index > 0 && index % 5 == 0) return _buildFeatureNews(article, index, isDark);
          
          // Card type 3 - Quick News List (for even indexes)
          if (index % 2 == 0 && index % 5 != 0) return _buildQuickNewsList(article, isDark);
          
          // Card type 1 - Standard News Card (default)
          return _buildStandardNewsCard(article, index, isDark);
        },
        childCount: displayNews.length,
      ),
    );
  }

  Widget _buildStandardNewsCard(Article article, int index, bool isDark) {
    final String heroTag = 'news_standard_${article.id}_$index';
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article, heroTag: heroTag))),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DesignTokens.cardColorOn(isDark),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    article.image,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 96, height: 96,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.textPrimaryOn(isDark),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: DesignTokens.textSecondaryOn(isDark),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentOrange.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              article.category.isNotEmpty ? article.category : 'समाचार',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.accentOrange,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${article.author} • ${article.date}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.7),
                              fontSize: 9,
                            ),
                          ),
                        ),
                        Icon(Icons.share_outlined, size: 15, color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.6)),
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

  Widget _buildFeatureNews(Article article, int index, bool isDark) {
    final String heroTag = 'news_feature_${article.id}_$index';
    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article, heroTag: heroTag))),
      child: Container(
        height: 240,
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: Image.network(
                article.image, 
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppColors.primaryDark.withOpacity(0.9)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${article.author} • ${article.date}',
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickNewsList(Article article, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: DesignTokens.textPrimaryOn(isDark),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right_rounded, size: 18, color: DesignTokens.textSecondaryOn(isDark)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${article.author} • ${article.date}',
              style: TextStyle(
                fontSize: 11,
                color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: DesignTokens.dividerOn(isDark)),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner() {
    if (_latestEdition == null) {
      // Default fallback if no magazines are published
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.magazineGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text(
              'विवेचना-ओज साहित्य ई-पत्रिका',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MagazinePage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentOrange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('मैगज़ीन पेज पर जाएँ'),
            ),
          ],
        ),
      );
    }

    // Dynamic banner displaying the latest uploaded edition
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Layer Image
            Positioned.fill(
              child: Image.network(
                _latestEdition!.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryDark.withOpacity(0.95),
                      AppColors.primaryDark.withOpacity(0.8),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Book Thumbnail
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        _latestEdition!.coverUrl,
                        width: 70,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 70, height: 100, color: Colors.grey[800],
                          child: const Icon(Icons.book, color: Colors.white54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('नवीनतम संस्करण', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _latestEdition!.title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _latestEdition!.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const MagazinePage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryRed,
                            minimumSize: const Size(double.infinity, 36),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('मैगज़ीन पेज पर जाएँ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: List.generate(5, (index) => _buildSkeletonItem(isDark)),
      ),
    );
  }

  Widget _buildSkeletonItem(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.white;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 100, height: 100, decoration: BoxDecoration(color: containerColor, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: double.infinity, height: 16, color: containerColor),
                  const SizedBox(height: 8),
                  Container(width: double.infinity, height: 16, color: containerColor),
                  const SizedBox(height: 8),
                  Container(width: 60, height: 12, color: containerColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseIcon extends StatefulWidget {
  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 0.8, end: 1.2).animate(_controller),
      child: const Icon(Icons.flash_on, color: Colors.white, size: 18),
    );
  }
}

class _MarqueeText extends StatefulWidget {
  final String text;
  const _MarqueeText({required this.text});
  @override
  State<_MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<_MarqueeText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }
  void _startScrolling() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(seconds: widget.text.length ~/ 5),
          curve: Curves.linear,
        );
        await Future.delayed(const Duration(seconds: 1));
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    }
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(right: 200.0), // Padding to let it scroll off screen
        child: Text(
          widget.text, 
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          maxLines: 1,
        ),
      ),
    );
  }
}

class _CategoryHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabController _tabController;
  final List<String> _categories;
  final bool _isDark;
  final Function(String) _onCategoryChanged;

  _CategoryHeaderDelegate(this._tabController, this._categories, this._isDark, this._onCategoryChanged);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final bg = DesignTokens.scaffoldOn(_isDark);
    final selectedBg = AppColors.primaryRed;
    final unselectedBg = _isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final unselectedBorder = _isDark ? Colors.white24 : Colors.grey.shade300;
    final selectedText = Colors.white;
    final unselectedText = _isDark ? Colors.white70 : AppColors.textPrimaryLight;

    return Container(
      color: bg,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: Colors.transparent,
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        tabs: _categories.map((cat) {
          final isSelected = _tabController.index == _categories.indexOf(cat);
          return Tab(
            height: 36,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? selectedBg : unselectedBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.transparent : unselectedBorder,
                  width: 1,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  color: isSelected ? selectedText : unselectedText,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }).toList(),
        onTap: (index) {
          _onCategoryChanged(_categories[index]);
        },
      ),
    );
  }

  @override
  double get maxExtent => 52.0; // Reduced height to prevent overflow
  @override
  double get minExtent => 52.0;
  @override
  bool shouldRebuild(covariant _CategoryHeaderDelegate oldDelegate) {
    return oldDelegate._tabController.index != _tabController.index ||
           oldDelegate._isDark != _isDark;
  }
}

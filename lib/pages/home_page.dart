import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../utils/app_routes.dart';
import '../widgets/hero_section.dart';
import '../widgets/featured_writers.dart';
import '../widgets/news_reel_hero_carousel.dart';
import 'profile_page.dart';
import 'news_page.dart';
import 'writer_registration_page.dart';
import 'magazine_page.dart';
import 'writer_articles_feed_page.dart';
import '../services/magazine_service.dart';
import '../models/magazine_edition.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/notification_service.dart';
import 'admin_dashboard_page.dart';
import '../providers/theme_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final MagazineService _magazineService = MagazineService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  MagazineEdition? _featuredMagazine;
  bool _magazineLoading = true;
  StreamSubscription<List<MagazineEdition>>? _magazineSub;
  StreamSubscription<QuerySnapshot>? _notificationSub;
  Map<String, dynamic>? _featuredArticles;

  // GlobalKeys to trigger refresh() on child widget states
  final GlobalKey<NewsReelHeroCarouselState> _reelKey =
      GlobalKey<NewsReelHeroCarouselState>();
  final GlobalKey<HeroSectionState> _heroKey = GlobalKey<HeroSectionState>();

  @override
  void initState() {
    super.initState();
    _loadArticles();
    _loadFeaturedMagazine();
    // Request notification permission when home page loads
    NotificationService().requestPermission();
    _listenForInAppNotifications();
  }

  void _listenForInAppNotifications() {
     final user = FirebaseAuth.instance.currentUser;
     if (user == null) return;
     
     _notificationSub = FirebaseFirestore.instance
         .collection('user_notifications')
         .where('userId', isEqualTo: user.uid)
         .where('isRead', isEqualTo: false)
         .snapshots()
         .listen((snapshot) async {
             if (!mounted || snapshot.docs.isEmpty) return;
             
             // To prevent multiple dialogs stacking, we process documents and mark them as read.
             // We only show a dialog if a new "added" change is detected that we haven't processed.
             
             final List<DocumentSnapshot> newDocs = [];
             for (var change in snapshot.docChanges) {
                 if (change.type == DocumentChangeType.added) {
                     newDocs.add(change.doc);
                 }
             }
             
             if (newDocs.isEmpty) return;

             // Mark all these processed notifications as read in Firestore
             final WriteBatch batch = FirebaseFirestore.instance.batch();
             for (var doc in newDocs) {
                 batch.update(doc.reference, {'isRead': true});
             }
             
             try {
                await batch.commit();
             } catch (e) {
                debugPrint('Failed to mark notifications as read: $e');
                // Even if update fails, we should still show the dialog once.
             }

             if (!mounted) return;

             // Show the most relevant notification or a summary
             final firstData = newDocs.first.data() as Map<String, dynamic>;
             final String title = newDocs.length > 1 
                ? 'नई सूचनाएँ (${newDocs.length})' 
                : (firstData['title'] ?? 'सूचना');
             
             final String body = newDocs.length > 1
                ? '${newDocs.length} नई सूचनाएँ प्राप्त हुईं। विवरण देखने के लिए कृपया जाँचें।'
                : (firstData['body'] ?? '');

             showDialog(
                 context: context,
                 builder: (_) => AlertDialog(
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                     icon: const Icon(Icons.info_outline, color: AppColors.primaryRed, size: 48),
                     title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                     content: Text(body, textAlign: TextAlign.center),
                     actions: [
                         TextButton(
                             onPressed: () => Navigator.pop(context),
                             child: const Text('ठीक है (OK)'),
                         ),
                     ],
                 ),
             );
         });
  }

  @override
  void dispose() {
    _magazineSub?.cancel();
    _notificationSub?.cancel();
    super.dispose();
  }

  void _loadFeaturedMagazine() {
    _magazineSub = _magazineService.getMagazinesStream().listen((magazines) {
      if (mounted) {
        if (magazines.isNotEmpty) {
          setState(() {
            _featuredMagazine = magazines.first;
            _magazineLoading = false;
          });
        } else {
          setState(() {
            _featuredMagazine = null;
            _magazineLoading = false;
          });
        }
      }
    }, onError: (_) {
      if (mounted) setState(() => _magazineLoading = false);
    });
  }

  /// Refreshes all sections: reels, trending hero, and magazine stream.
  Future<void> _refreshHomeData() async {
    // Reload widget-owned sections via their GlobalKeys
    await Future.wait([
      _reelKey.currentState?.refresh() ?? Future.value(),
      _heroKey.currentState?.refresh() ?? Future.value(),
    ]);
    // Magazine stream auto-updates via Firestore; reset loading so skeleton shows briefly
    if (mounted) setState(() => _magazineLoading = true);
    _magazineSub?.cancel();
    _loadFeaturedMagazine();
  }

  Future<void> _loadArticles() async {
    // Kept for potential future use â€” loading handled by child widgets
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode;

    return Scaffold(
      extendBody: false,
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      body: _AnimatedIndexedStack(
        index: _currentIndex,
        children: [
          _buildEditorialHome(isDark),
          const NewsPage(),
          const WriterArticlesFeedPage(),
          const MagazinePage(),
          const ProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  // â”€â”€ Editorial Home Tab â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildEditorialHome(bool isDark) {
    return RefreshIndicator(
      onRefresh: _refreshHomeData,
      color: AppColors.accentOrange,
      child: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          _buildDateBand(isDark),

          // News Reel Hero Section
          SliverToBoxAdapter(
            child: NewsReelHeroCarousel(key: _reelKey),
          ),

          // Hero Carousel (Top 5 Trending)
          SliverToBoxAdapter(
            child: HeroSection(key: _heroKey),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Featured Magazine (monthly) â€” skeleton while loading
          if (_magazineLoading)
            SliverToBoxAdapter(child: _buildMagazineSkeleton())
          else if (_featuredMagazine != null)
            SliverToBoxAdapter(child: _buildFeaturedMagazineCard(isDark)),

          const SliverToBoxAdapter(child: SizedBox(height: 12)),

          // Featured Writers (प्रमुख लेखक)
          const SliverToBoxAdapter(child: FeaturedWriters()),

          // Writers Feed Link
          SliverToBoxAdapter(child: _buildWriterFeedSection(isDark)),

          // Become a Writer CTA (only show if user is not a writer)
          SliverToBoxAdapter(
            child: StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                final user = authSnapshot.data;
                if (user == null) {
                  return _buildWriterCTA(isDark); // Show if not logged in
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('writer_registrations')
                      .where('uid', isEqualTo: user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    
                    return StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return const SizedBox.shrink();
                        }
                        
                        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                        final bool isAdmin = userData?['isAdmin'] == true || user.email == 'vivechanaoaj@gmail.com';
                        
                        final isWriter = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                        if (!isWriter && !isAdmin) {
                          return _buildWriterCTA(isDark);
                        }
                        return const SizedBox.shrink();
                      },
                    );
                  },
                );
              },
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      titleSpacing: 16,
      title: FadeInLeft(
        duration: const Duration(milliseconds: 500),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentOrange, width: 2),
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
                  'विवेचना-ओज',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimaryOn(isDark),
                    letterSpacing: 0.3,
                  ),
                ),
                Row(
                  children: [
                    Icon(
                      Icons.home_rounded,
                      size: 13,
                      color: AppColors.accentOrange,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'होम',
                      style: const TextStyle(
                        fontSize: 12,
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
      ),
      actions: [
        const ThemeToggleButton(),
        // Admin Dashboard Button (Conditional)
        StreamBuilder<User?>(
          stream: AuthService().authStateChanges,
          builder: (context, authSnapshot) {
            final user = authSnapshot.data;
            if (user == null) return const SizedBox.shrink();
            
            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                // Allow access if isAdmin is true OR if it's the specific admin email
                final bool isAdmin = userData?['isAdmin'] == true || user.email == 'vivechanaoaj@gmail.com';
                
                if (isAdmin) {
                  return IconButton(
                    icon: const Icon(Icons.admin_panel_settings, color: AppColors.primaryLight),
                    tooltip: 'Admin Dashboard',
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const AdminDashboardPage(),
                      ));
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            );
          },
        ),
        StreamBuilder<User?>(
          stream: AuthService().authStateChanges,
          builder: (context, snapshot) {
            final user = snapshot.data;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                onTap: () => setState(() => _currentIndex = 4),
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.15),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? Icon(Icons.person_outline, color: AppColors.primaryLight, size: 20)
                      : null,
                ),
              ),
            ),
          ],
        );
      },
    ),
  ],
);
}

  Widget _buildDateBand(bool isDark) {
    final now = DateTime.now();
    final weekdays = ['सोम', 'मंगल', 'बुध', 'गुरु', 'शुक्र', 'शनि', 'रवि'];
    final months = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    final dateStr = '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: DesignTokens.scaffoldOn(isDark),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: AppColors.accentOrange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              dateStr,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: DesignTokens.textSecondaryOn(isDark),
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'लाइव',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
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

  Widget _buildWriterFeedSection(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DesignTokens.dividerOn(isDark)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              AppRoutes.slideRight(const WriterArticlesFeedPage()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_stories, color: AppColors.primaryRed, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'साहित्य जगत',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.textPrimaryOn(isDark),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'रचनाकारों की कहानियां, कविताएं व लेख पढ़ें',
                        style: TextStyle(
                          fontSize: 13,
                          color: DesignTokens.textSecondaryOn(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: DesignTokens.textSecondaryOn(isDark)),
              ],
            ),
          ),
        ),
      ),
    );
  }  Widget _buildWriterCTA(bool isDark) {
    return GestureDetector(
      onTap: () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null || user.isAnonymous) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लेखक बनने के लिए कृपया पहले लॉगिन करें।')),
          );
          // Optional: Force them out of the guest session
          // await AuthService().signOut(); 
          return;
        }
        
        Navigator.push(
          context,
          AppRoutes.slideUp(const WriterRegistrationPage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: AppColors.magazineGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryRed.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'क्या आप भी लिखना चाहते हैं?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'अपने विचार, लेख और कहानियां विवेचना-ओज के पाठकों तक पहुंचाएं।',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'लेखक बनें  →',
                style: TextStyle(
                  color: AppColors.primaryRed,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom Navigation ───────────────────────────────────────────────────
  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label, bool isDark) {
    final isSelected = _currentIndex == index;
    final activeColor = AppColors.primaryRed;
    final inactiveColor = DesignTokens.textSecondaryOn(isDark);

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: isSelected 
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: isSelected ? activeColor : inactiveColor,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E).withOpacity(0.95) : Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'होम', isDark),
            _buildNavItem(1, Icons.newspaper_rounded, Icons.newspaper_outlined, 'न्यूज़', isDark),
            _buildNavItem(2, Icons.auto_stories_rounded, Icons.auto_stories_outlined, 'साहित्य', isDark),
            _buildNavItem(3, Icons.menu_book_rounded, Icons.menu_book_outlined, 'मैगज़ीन', isDark),
            _buildNavItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'प्रोफ़ाइल', isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedMagazineCard(bool isDark) {
    if (_featuredMagazine == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        if (!_featuredMagazine!.isUploaded) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              icon: const Icon(Icons.hourglass_top_rounded, color: AppColors.accentOrange, size: 48),
              title: const Text('जल्द आ रहा है!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              content: Text(
                '${_featuredMagazine!.title} का अंक अभी अपलोड नहीं किया गया है। कृपया कुछ समय बाद पुनः प्रयास करें।',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ठीक है', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          );
          return;
        }
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MagazinePage()),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background image (portrait)
              Image.network(
                _featuredMagazine!.coverUrl,
                width: double.infinity,
                height: 380,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 380,
                  color: AppColors.primaryDark,
                  child: const Icon(Icons.book_rounded, color: Colors.white54, size: 60),
                ),
              ),
              // Gradient overlay
              Container(
                width: double.infinity,
                height: 380,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    stops: const [0.3, 1.0],
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'नवीनतम अंक',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _featuredMagazine!.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _featuredMagazine!.subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Magazine skeleton — same height as the real card ─────────────────────
  Widget _buildMagazineSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 380,
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// â”€â”€ Animated IndexedStack â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
/// Preserves state of ALL children (like IndexedStack) while
/// animating the incoming tab with a fade + gentle scale-up.
class _AnimatedIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const _AnimatedIndexedStack({
    required this.index,
    required this.children,
  });

  @override
  State<_AnimatedIndexedStack> createState() => _AnimatedIndexedStackState();
}

class _AnimatedIndexedStackState extends State<_AnimatedIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward(from: 1.0); // start complete â€” no animation on first load
  }

  @override
  void didUpdateWidget(_AnimatedIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      setState(() => _currentIndex = widget.index);
      _controller.forward(from: 0); // animate in the new tab
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      children: widget.children.asMap().entries.map((entry) {
        final isActive = entry.key == _currentIndex;
        return isActive
            ? FadeTransition(
                opacity: _opacity,
                child: ScaleTransition(
                  scale: _scale,
                  alignment: Alignment.topCenter,
                  child: entry.value,
                ),
              )
            : entry.value;
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMOOTH THEME TOGGLE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class ThemeToggleButton extends StatefulWidget {
  const ThemeToggleButton({super.key});

  @override
  State<ThemeToggleButton> createState() => _ThemeToggleButtonState();
}

class _ThemeToggleButtonState extends State<ThemeToggleButton> {
  bool? _localIsDark; 
  bool _isAnimating = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    // Use local override while animating, otherwise sync with global state
    final isDark = _localIsDark ?? provider.isDarkMode;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: GestureDetector(
          onTap: () async {
            if (_isAnimating) return;
            _isAnimating = true;

            // 1. Immediately toggle local state to trigger smooth 60fps visual animation.
            setState(() {
              _localIsDark = !provider.isDarkMode;
            });

            // 2. Give the slider button a guaranteed isolated window to finish its UI trace
            // before the heavy global `ThemeData` recompilation stalls the UI thread.
            await Future.delayed(const Duration(milliseconds: 200));

            // 3. Trigger the actual global app theme rewrite.
            provider.toggleTheme();

            if (mounted) {
              setState(() {
                _localIsDark = null;
                _isAnimating = false;
              });
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            width: 52,
            height: 30,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : AppColors.primaryRed.withOpacity(0.12),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.primaryRed.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => RotationTransition(
                    turns: Tween<double>(begin: 0.5, end: 1.0).animate(anim),
                    child: FadeTransition(opacity: anim, child: child),
                  ),
                  child: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    key: ValueKey<bool>(isDark),
                    size: 14,
                    color: isDark ? Colors.amber : AppColors.primaryRed,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

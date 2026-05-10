import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';
import '../models/article.dart';
import '../pages/article_detail_page.dart';
import '../services/news_service.dart';
import '../utils/app_routes.dart';

class HeroSection extends StatefulWidget {
  const HeroSection({super.key});

  @override
  State<HeroSection> createState() => HeroSectionState();
}

/// State is public so HomePage can call `refresh()` via GlobalKey.
class HeroSectionState extends State<HeroSection> with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final NewsService _newsService = NewsService();
  int _currentPage = 0;
  List<Article> _featuredArticles = [];
  bool _isLoading = true;
  bool _hasError = false;
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNews();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_lastFetchTime == null ||
          DateTime.now().difference(_lastFetchTime!).inMinutes >= 15) {
        _loadNews();
      }
    }
  }

  /// Called by HomePage on pull-to-refresh.
  Future<void> refresh() async {
    await _loadNews();
  }

  Future<void> _loadNews() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await _newsService.fetchNews();
      final List<Article> news = response['articles'] as List<Article>;
      if (mounted) {
        setState(() {
          _featuredArticles = news.take(5).toList();
          _isLoading = false;
          _lastFetchTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_hasError) return _buildErrorState();
    if (_featuredArticles.isEmpty) return _buildErrorState();

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _featuredArticles.length,
            itemBuilder: (context, index) =>
                _buildHeroCard(_featuredArticles[index], context, index),
          ),
          PositionImageDots(
            total: _featuredArticles.length,
            current: _currentPage,
          ),
        ],
      ),
    );
  }

  // ── Shimmer skeleton — same 300-height as the real carousel ─────────────
  Widget _buildSkeleton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.white;
    final blockColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return SizedBox(
      height: 300,
      child: Shimmer.fromColors(
        baseColor: baseColor,
        highlightColor: highlightColor,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 0),
          decoration: BoxDecoration(
            color: containerColor,
            borderRadius: BorderRadius.circular(0),
          ),
          child: Stack(
            children: [
              // Fake image block
              Container(color: containerColor),
              // Fake text overlay at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 130,
                  padding: const EdgeInsets.all(24),
                  color: containerColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                          height: 12, width: 80, color: blockColor),
                      const SizedBox(height: 10),
                      Container(
                          height: 20,
                          width: double.infinity,
                          color: blockColor),
                      const SizedBox(height: 6),
                      Container(
                          height: 20, width: 220, color: blockColor),
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

  // ── Error / empty state — preserves 300-height ───────────────────────────
  Widget _buildErrorState() {
    return SizedBox(
      height: 300,
      child: Container(
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'समाचार लोड नहीं हो सका',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _loadNews,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'पुनः प्रयास करें',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard(Article article, BuildContext context, int index) {
    final String heroTag = 'hero_article_${article.id}_$index';
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          AppRoutes.slideUp(
              ArticleDetailPage(article: article, heroTag: heroTag)),
        );
      },
      child: FadeIn(
        duration: const Duration(milliseconds: 800),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: heroTag,
              child: AnimatedScale(
                scale: 1.05,
                duration: const Duration(seconds: 10),
                curve: Curves.linear,
                child: Image.network(
                  article.image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.grey[800],
                    child: const Icon(Icons.broken_image,
                        color: Colors.white54, size: 40),
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
                    AppColors.primaryDark.withOpacity(0.85),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accentOrange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article.category,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    article.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(article.author,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(article.readTime,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12)),
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
}

class PositionImageDots extends StatelessWidget {
  final int total;
  final int current;

  const PositionImageDots(
      {super.key, required this.total, required this.current});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      right: 24,
      child: Row(
        children: List.generate(
          total,
          (index) => Container(
            width: index == current ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.only(left: 4),
            decoration: BoxDecoration(
              color: index == current
                  ? AppColors.accentOrange
                  : Colors.white54,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

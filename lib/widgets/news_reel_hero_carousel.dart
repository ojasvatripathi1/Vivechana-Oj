import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../models/news_reel.dart';
import '../services/reel_service.dart';
import '../constants/app_colors.dart';
import '../pages/reel_feed_page.dart';

class NewsReelHeroCarousel extends StatefulWidget {
  const NewsReelHeroCarousel({super.key});

  @override
  State<NewsReelHeroCarousel> createState() => NewsReelHeroCarouselState();
}

/// State is public so HomePage can call `refresh()` via GlobalKey.
class NewsReelHeroCarouselState extends State<NewsReelHeroCarousel> {
  final ReelService _reelService = ReelService();
  
  // Global collections of reels
  List<NewsReel> _youtubeReels = [];
  bool _ytLoading = false;

  @override
  void initState() {
    super.initState();
    _startYouTubeFetch();
  }

  /// Refreshes all data
  Future<void> refresh() async {
    debugPrint('NewsReelHeroCarousel: Manual Refresh triggered');
    setState(() {
      _youtubeReels = [];
      _ytLoading = true;
    });
    // Clear static cache in service to force fresh fetch
    ReelService.clearCache();
    await _startYouTubeFetch();
  }

  Future<void> _startYouTubeFetch() async {
    if (!mounted) return;
    setState(() => _ytLoading = true);
    
    try {
      debugPrint('NewsReelHeroCarousel: Starting background YouTube fetch...');
      // We use the service to get all YouTube reels
      final ytReels = await _reelService.getYouTubeReels();
      
      if (mounted) {
        setState(() {
          _youtubeReels = ytReels;
          _ytLoading = false;
        });
        debugPrint('NewsReelHeroCarousel: YouTube fetch complete with ${ytReels.length} reels');
      }
    } catch (e) {
      debugPrint('NewsReelHeroCarousel: YouTube fetch failed: $e');
      if (mounted) setState(() => _ytLoading = false);
    }
  }

  List<NewsReel> _combineAndSort(List<NewsReel> firestore) {
    final combined = [...firestore, ..._youtubeReels];
    // Remove duplicates by ID
    final seen = <String>{};
    final unique = combined.where((r) => seen.add(r.id)).toList();
    unique.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return unique;
  }

  void _openReelFeed(List<NewsReel> allReels, int initialIndex) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ReelFeedPage(reels: allReels, initialIndex: initialIndex),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<NewsReel>>(
      stream: _reelService.getReelsStream(),
      builder: (context, snapshot) {
        final firestoreReels = snapshot.data ?? [];
        final allReels = _combineAndSort(firestoreReels);
        
        // We show shimmer if:
        // 1. Connection is waiting AND we have nothing yet (YT or FS)
        // 2. OR everything is empty AND we are still loading YouTube
        final showShimmer = (snapshot.connectionState == ConnectionState.waiting && _youtubeReels.isEmpty) ||
                           (allReels.isEmpty && _ytLoading);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section header ─────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.slow_motion_video_rounded,
                      color: AppColors.primaryRed, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'ताज़ा न्यूज़ रील्स',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.grey.shade800),
                  ),
                  if (_ytLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primaryRed),
                    ),
                  ],
                ],
              ),
            ),

            // ── Carousel area ─────────────────────────────────────────────
            SizedBox(
              height: 220,
              child: showShimmer
                  ? _buildShimmer()
                  : allReels.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: allReels.length + (_ytLoading ? 2 : 0),
                          itemBuilder: (context, index) {
                            if (index >= allReels.length) return _ShimmerCard();
                            return GestureDetector(
                              onTap: () => _openReelFeed(allReels, index),
                              child: _ReelCard(reel: allReels[index]),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: GestureDetector(
        onTap: refresh,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.refresh_rounded, color: AppColors.primaryRed, size: 28),
            const SizedBox(height: 8),
            const Text(
              'रील्स लोड नहीं हुईं',
              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'पुनः प्रयास करें',
              style: TextStyle(color: AppColors.primaryRed, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 5,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }


  Widget _buildErrorState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: 4,
      itemBuilder: (_, __) => _ErrorCard(onRetry: refresh),
    );
  }
}

// ── Error card — keeps layout intact ────────────────────────────────────────
class _ErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.grey.shade400, size: 28),
          const SizedBox(height: 8),
          Text('लोड नहीं हुआ',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('पुनः प्रयास',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer loading card ───────────────────────────────────────────────────────
class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade300,
      highlightColor: isDark ? const Color(0xFF3D3D3D) : Colors.grey.shade100,
      child: Container(
        width: 130,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// ── Main reel thumbnail card ──────────────────────────────────────────────────
class _ReelCard extends StatelessWidget {
  final NewsReel reel;
  const _ReelCard({required this.reel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(2, 3)),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Thumbnail
          if (reel.thumbnailUrl != null && reel.thumbnailUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                reel.thumbnailUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Shimmer.fromColors(
                    baseColor: Colors.grey.shade800,
                    highlightColor: Colors.grey.shade600,
                    child: Container(color: Colors.grey.shade800),
                  );
                },
                errorBuilder: (_, __, ___) => const _FallbackThumbnail(),
              ),
            )
          else
            const _FallbackThumbnail(),

          // Dark gradient overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.25),
                  Colors.black.withOpacity(0.82),
                ],
                stops: const [0.4, 0.65, 1.0],
              ),
            ),
          ),

          // Play icon
          const Align(
            alignment: Alignment.center,
            child:
                Icon(Icons.play_circle_fill, color: Colors.white70, size: 42),
          ),

          // Title
          Positioned(
            bottom: 10,
            left: 8,
            right: 8,
            child: Text(
              reel.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),

          // Source badge
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryRed,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    reel.type == ReelType.youtube
                        ? Icons.play_arrow
                        : Icons.movie,
                    color: Colors.white,
                    size: 9,
                  ),
                  const SizedBox(width: 2),
                  const Text('Shorts',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackThumbnail extends StatelessWidget {
  const _FallbackThumbnail();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.movie_creation_outlined,
              color: Colors.white54, size: 30),
        ),
      ),
    );
  }
}

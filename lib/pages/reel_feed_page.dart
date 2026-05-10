import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/news_reel.dart';
import '../constants/app_colors.dart';

class ReelFeedPage extends StatefulWidget {
  final List<NewsReel> reels;
  final int initialIndex;

  const ReelFeedPage({
    super.key,
    required this.reels,
    this.initialIndex = 0,
  });

  @override
  State<ReelFeedPage> createState() => _ReelFeedPageState();
}

class _ReelFeedPageState extends State<ReelFeedPage> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    // Force portrait for reel playback
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Restore orientations
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reels.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, iconTheme: const IconThemeData(color: Colors.white)),
        body: const Center(child: Text('कोई न्यूज़ रील उपलब्ध नहीं है।', style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('न्यूज़ रील्स', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.reels.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final reel = widget.reels[index];
          return _ReelPlayerItem(
            key: ValueKey(reel.id), // Ensures widget is recreated per reel
            reel: reel,
            isActive: index == _currentIndex,
          );
        },
      ),
    );
  }
}

// ─── Individual Reel Player Item ─────────────────────────────────────────────
class _ReelPlayerItem extends StatefulWidget {
  final NewsReel reel;
  final bool isActive;

  const _ReelPlayerItem({
    super.key,
    required this.reel,
    required this.isActive,
  });

  @override
  State<_ReelPlayerItem> createState() => _ReelPlayerItemState();
}

class _ReelPlayerItemState extends State<_ReelPlayerItem> {
  YoutubePlayerController? _ytController;
  VideoPlayerController? _nativeController;
  bool _isPlaying = true;
  bool _nativeInitialized = false;

  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initPlayer(delay: false);
    }
  }

  Future<void> _initPlayer({bool delay = true}) async {
    if (_isInitializing || _ytController != null || _nativeController != null) return;
    _isInitializing = true;

    // Delay initialization so scroll animation completes perfectly smoothly.
    if (delay) {
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (!mounted || !widget.isActive) {
      _isInitializing = false;
      return;
    }

    if (widget.reel.type == ReelType.youtube) {
      final videoId = widget.reel.videoUrl;
      _ytController = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          loop: true,
          isLive: false,
          forceHD: false,
          hideThumbnail: true,
          hideControls: true,
          disableDragSeek: true,
        ),
      );
      if (mounted) setState(() {});
    } else {
      _nativeController = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
        ..initialize().then((_) {
          if (mounted && widget.isActive) {
            _nativeController!.setLooping(true);
            _nativeController!.play();
            setState(() => _nativeInitialized = true);
          }
        }).catchError((e) {
          debugPrint('Native video init error: $e');
        });
    }
    _isInitializing = false;
  }

  @override
  void didUpdateWidget(covariant _ReelPlayerItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      if (widget.isActive) {
        _initPlayer(delay: true);
        setState(() => _isPlaying = true);
      } else {
        _disposePlayer();
        setState(() => _isPlaying = false);
      }
    }
  }

  void _disposePlayer() {
    _ytController?.dispose();
    _ytController = null;
    _nativeController?.dispose();
    _nativeController = null;
    _nativeInitialized = false;
    _isInitializing = false;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _ytController?.play();
      _nativeController?.play();
    } else {
      _ytController?.pause();
      _nativeController?.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget playerWidget;

    if (widget.reel.type == ReelType.youtube) {
      if (_ytController != null) {
        playerWidget = SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.contain, // Use contain to prevent cropping landscape YouTube videos
            child: SizedBox(
              // YouTube player renders at 16:9; we size it to screen width so
              // FittedBox can scale it to fit the portrait frame.
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.width * 9 / 16,
              child: YoutubePlayerBuilder(
                player: YoutubePlayer(
                  controller: _ytController!,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: AppColors.primaryRed,
                  progressColors: const ProgressBarColors(
                    playedColor: AppColors.primaryRed,
                    handleColor: AppColors.primaryLight,
                  ),
                ),
                builder: (context, player) => player,
              ),
            ),
          ),
        );
      } else {
        playerWidget = const SizedBox.shrink(); // Covered by thumbnail while initializing
      }
    } else if (widget.reel.type == ReelType.native) {
      if (_nativeController != null && _nativeInitialized) {
        final double aspectRatio = _nativeController!.value.aspectRatio;
        // If aspect ratio > 1, it is landscape. Use BoxFit.contain.
        // If aspect ratio < 1, it is portrait. Use BoxFit.cover for immersion.
        final bool isLandscape = aspectRatio > 1.0;

        playerWidget = SizedBox.expand(
          child: FittedBox(
            fit: isLandscape ? BoxFit.contain : BoxFit.cover,
            child: SizedBox(
              width: _nativeController!.value.size.width,
              height: _nativeController!.value.size.height,
              child: VideoPlayer(_nativeController!),
            ),
          ),
        );
      } else {
        playerWidget = const SizedBox.shrink();
      }
    } else {
      playerWidget = const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: _togglePlay,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video ──────────────────────────────────────────────────────────
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: playerWidget,
          ),

          // ── Thumbnail background while player loading ─────────────────────
          if (widget.reel.thumbnailUrl != null)
            if (widget.reel.type == ReelType.youtube && _ytController == null)
              Image.network(
                widget.reel.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              )
            else if (widget.reel.type == ReelType.youtube && _ytController != null)
              ValueListenableBuilder<YoutubePlayerValue>(
                valueListenable: _ytController!,
                builder: (context, value, child) {
                  // Hide the thumbnail when playing or when it has already played
                  bool isVideoVisible = value.isPlaying || value.hasPlayed || value.playerState == PlayerState.playing;
                  if (!isVideoVisible) {
                    return Image.network(
                      widget.reel.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    );
                  }
                  return const SizedBox.shrink();
                },
              )
            else if (widget.reel.type == ReelType.native && !_nativeInitialized)
              Image.network(
                widget.reel.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),

          // ── Play/Pause overlay ────────────────────────────────────────────
          if (!_isPlaying)
            Center(
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 54),
              ),
            ),

          // ── Bottom info overlay ───────────────────────────────────────────
          Positioned(
            bottom: 24,
            left: 16,
            right: 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('LIVE NEWS REEL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.reel.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.3,
                    shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.access_time_rounded, color: Colors.white70, size: 12),
                  const SizedBox(width: 4),
                  Text(timeago.format(widget.reel.createdAt, locale: 'en'), style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ],
            ),
          ),

          // ── Swipe-up hint ─────────────────────────────────────────────────
          Positioned(
            bottom: 8,
            right: 0,
            left: 0,
            child: Center(
              child: Column(
                children: const [
                  Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white54, size: 20),
                  Text('स्वाइप करें', style: TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

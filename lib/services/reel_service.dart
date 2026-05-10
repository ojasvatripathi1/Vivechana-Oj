import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/news_reel.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'storage_service.dart';

class ReelService {
  final CollectionReference _reelsCollection =
      FirebaseFirestore.instance.collection('news_reels');

  // ── In-memory cache for YouTube RSS results ───────────────────────────────
  static List<NewsReel>? _ytCache;
  static DateTime? _ytCacheTime;
  // Extended to 15 min to reduce fetch frequency and mask intermittent failures
  static const _cacheExpiry = Duration(minutes: 15);

  static void clearCache() {
    _ytCache = null;
    _ytCacheTime = null;
  }

  static bool get _isCacheValid =>
      _ytCache != null &&
      _ytCacheTime != null &&
      DateTime.now().difference(_ytCacheTime!) < _cacheExpiry;

  // ── 1. Firestore-only stream (instant, returns immediately) ───────────────
  Stream<List<NewsReel>> getReelsStream() {
    // NOTE: We don't use .orderBy() to avoid "Missing Index" errors.
    // Sorting is handled in-memory instead.
    return _reelsCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            try {
              return NewsReel.fromFirestore(doc);
            } catch (e) {
              debugPrint('Error parsing news reel ${doc.id}: $e');
              return null;
            }
          })
          .whereType<NewsReel>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // ── 2. Cached YouTube fetch (background, non-blocking) ────────────────────
  Future<List<NewsReel>> getYouTubeReels() async {
    if (_isCacheValid) return _ytCache!;

    final reels = await fetchYouTubeShorts();
    // Only cache when we actually got results — prevents caching empty lists
    if (reels.isNotEmpty) {
      _ytCache = reels;
      _ytCacheTime = DateTime.now();
    }
    return reels;
  }

  // Known Hindi News channel IDs — ordered roughly by reliability
  final List<MapEntry<String, String>> _youtubeChannels = [
    MapEntry('Aaj Tak', 'UCYPvAwZP8pZhSMW8qs7cVCw'),
    MapEntry('ABP News', 'UCRWFSbif-RFENbBrSiez1DA'),
    MapEntry('India TV', 'UCttspZesZIDEwwpVIgoZtWQ'),
    MapEntry('Zee News', 'UCIvaYmXn910QMdemBG3v1pQ'),
    MapEntry('Republic Bharat', 'UCilbgr035NJ7BIkVPMeLyWA'),
    MapEntry('NDTV India', 'UCZFMm1mMw0F81Z37aaEzTUA'),
    MapEntry('News18 India', 'UC3BCHNdM3AR-axEb5AHNrxw'),
  ];

  /// Fetches the latest videos from all channel RSS feeds in parallel.
  /// Retries once automatically if the first attempt yields nothing.
  Future<List<NewsReel>> fetchYouTubeShorts({bool isRetry = false}) async {
    final List<NewsReel> ytReels = [];

    // Build one Future per channel — each catches its own errors so a single
    // slow/blocked channel never prevents the rest from succeeding.
    final futures = _youtubeChannels.map((entry) => _fetchChannelReels(
          channelName: entry.key,
          channelId: entry.value,
        ));

    // eagerError: false → wait for ALL futures regardless of individual failures
    List<List<NewsReel>> results;
    try {
      results = await Future.wait(futures, eagerError: false);
    } catch (e) {
      debugPrint('ReelService: Future.wait outer error: $e');
      results = [];
    }

    for (final list in results) {
      ytReels.addAll(list);
    }

    debugPrint('ReelService: Total YouTube reels fetched: ${ytReels.length}');

    // Auto-retry once if we got nothing (network may have been momentarily slow)
    if (ytReels.isEmpty && !isRetry) {
      debugPrint('ReelService: No reels — retrying in 3 seconds...');
      await Future.delayed(const Duration(seconds: 3));
      return fetchYouTubeShorts(isRetry: true);
    }

    return ytReels;
  }

  /// Fetches videos for a single YouTube channel RSS feed.
  /// Returns an empty list on any error so the caller always gets a valid value.
  Future<List<NewsReel>> _fetchChannelReels({
    required String channelName,
    required String channelId,
  }) async {
    final rssUrl =
        'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
    try {
      debugPrint('ReelService: Fetching RSS for $channelName ($channelId)');
      final response = await http.get(
        Uri.parse(rssUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (compatible; VivechanaApp/1.0)',
          'Accept': 'application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 12)); // Increased from 8 s

      debugPrint(
          'ReelService: $channelName -> status ${response.statusCode}, bytes: ${response.bodyBytes.length}');

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final document = XmlDocument.parse(response.body);
        final entries = document.findAllElements('entry').take(4);

        final List<NewsReel> channelReels = [];
        for (final element in entries) {
          final videoId =
              element.findElements('yt:videoId').firstOrNull?.innerText;
          final title =
              element.findElements('title').firstOrNull?.innerText;
          final published =
              element.findElements('published').firstOrNull?.innerText;

          if (videoId != null &&
              videoId.isNotEmpty &&
              title != null &&
              title.isNotEmpty) {
            final DateTime parsedDate =
                DateTime.tryParse(published ?? '') ?? DateTime.now();

            channelReels.add(NewsReel(
              id: 'yt_$videoId',
              title: '$channelName: $title',
              type: ReelType.youtube,
              videoUrl: videoId,
              thumbnailUrl: YoutubePlayer.getThumbnail(videoId: videoId),
              createdAt: parsedDate,
            ));
          }
        }
        debugPrint(
            'ReelService: Parsed ${channelReels.length} reels from $channelName');
        return channelReels;
      } else {
        debugPrint(
            'ReelService: Non-200 or empty body for $channelName: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ReelService: ERROR fetching $channelName RSS: $e');
    }
    return <NewsReel>[];
  }

  /// Add a new reel (Native or YouTube) to Firestore from the Admin Dashboard
  Future<void> addReel(String title, String videoUrl, ReelType type,
      {String? thumbnailUrl}) async {
    String cleanUrl = videoUrl;
    String? cleanThumbnail = thumbnailUrl;

    if (type == ReelType.youtube) {
      // Extract the video ID from the URL if it's a youtube link
      final String? videoId = YoutubePlayer.convertUrlToId(videoUrl);
      if (videoId != null) {
        cleanUrl = videoId;
        // Generate YouTube thumbnail
        cleanThumbnail = YoutubePlayer.getThumbnail(videoId: videoId);
      }
    }

    await _reelsCollection.add({
      'title': title,
      'type': type == ReelType.youtube ? 'youtube' : 'native',
      'videoUrl': cleanUrl, // For youtube, this is just the Video ID
      'thumbnailUrl': cleanThumbnail,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a reel and its associated video file from Storage if applicable
  Future<void> deleteReel(String reelId) async {
    try {
      final doc = await _reelsCollection.doc(reelId).get();
      if (doc.exists) {
        final reelData = doc.data() as Map<String, dynamic>?;
        if (reelData != null) {
          final type = reelData['type'] as String?;
          final videoUrl = reelData['videoUrl'] as String?;
          if (type == 'native' &&
              videoUrl != null &&
              videoUrl.isNotEmpty) {
            // Physically remove the MP4 file from Firebase Storage
            await StorageService.deleteByUrl(videoUrl);
          }
        }
      }
      await _reelsCollection.doc(reelId).delete();
    } catch (e) {
      debugPrint('Error deleting reel: $e');
      rethrow;
    }
  }
}

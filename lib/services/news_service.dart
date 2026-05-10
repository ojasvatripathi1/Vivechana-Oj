import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/article.dart';

class NewsService {
  // ── In-memory cache (fast path for same-session repeated calls) ──────────
  final Map<String, Map<String, dynamic>> _memoryCache = {};

  // ── Persistent cache settings ────────────────────────────────────────────
  // Cache lives 15 minutes — long enough to survive app kills on low-RAM
  // Indian Android devices, short enough for news to feel fresh.
  static const Duration _cacheDuration = Duration(minutes: 15);
  static const String _cachePrefix = 'news_cache_v1_';

  // HTTP timeout reduced to 6s — better UX on slow 4G than a 10s hang.
  static const Duration _httpTimeout = Duration(seconds: 6);

  /// Returns cached articles for [key] if still within [_cacheDuration], else null.
  /// Checks in-memory first (fast), then SharedPreferences (persistent).
  Future<List<Article>?> _getCachedArticles(String key) async {
    // 1. In-memory fast path
    final mem = _memoryCache[key];
    if (mem != null) {
      final ts = mem['timestamp'] as DateTime;
      if (DateTime.now().difference(ts) < _cacheDuration) {
        return mem['articles'] as List<Article>;
      }
    }

    // 2. Persistent cache (SharedPreferences)
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final tsMs = decoded['ts'] as int?;
      if (tsMs == null) return null;

      final ts = DateTime.fromMillisecondsSinceEpoch(tsMs);
      if (DateTime.now().difference(ts) >= _cacheDuration) return null;

      final articlesJson = decoded['articles'] as List<dynamic>? ?? [];
      final articles = articlesJson
          .map((e) => Article.fromJson(e as Map<String, dynamic>))
          .toList();

      // Warm the in-memory cache from disk
      _memoryCache[key] = {'articles': articles, 'timestamp': ts};
      return articles;
    } catch (e) {
      debugPrint('[NewsService] Persistent cache read error for $key: $e');
      return null;
    }
  }

  /// Saves [articles] to both in-memory and SharedPreferences caches.
  Future<void> _setCachedArticles(String key, List<Article> articles) async {
    final now = DateTime.now();
    _memoryCache[key] = {'articles': articles, 'timestamp': now};

    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'ts': now.millisecondsSinceEpoch,
        'articles': articles.map((a) => a.toJson()).toList(),
      });
      await prefs.setString('$_cachePrefix$key', payload);
    } catch (e) {
      // Persistence failure is non-fatal — in-memory cache still works.
      debugPrint('[NewsService] Persistent cache write error for $key: $e');
    }
  }

  final Map<String, String> _rssFeeds = {
    'सभी': 'https://feeds.bbci.co.uk/hindi/rss.xml',
    'भारत': 'https://feeds.bbci.co.uk/hindi/india/rss.xml',
    'विश्व': 'https://feeds.bbci.co.uk/hindi/international/rss.xml',
  };
  final Map<String, String> _fallbackFeeds = {
    // Left empty — most third-party Hindi RSS feeds are unreliable.
    // Bing News RSS is used as the final fallback.
  };

  // Fallback images map by category (Multiple to avoid repetition)
  final Map<String, List<String>> _categoryImages = {
    'सभी': [
       'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1585829365295-ab7cd400c167?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1504711434969-e33886168f5c?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1588681664899-f142ff2dc9b1?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1444653614773-995cb1ef9efa?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1508921340878-ba53e1f016ec?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1557425955-df376b5903c8?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1503694978374-8a2fa686963a?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1526470608268-f674ce90ebd4?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1523995462485-3d171b5c8fa9?q=80&w=1000&auto=format&fit=crop',
    ],
    'भारत': [
       'https://images.unsplash.com/photo-1532375810709-75b1da00537c?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1524492412937-b28074a5d7da?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1514222134-b57cbb8ce073?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1587474260584-136574528ed5?q=80&w=1000&auto=format&fit=crop',
    ],
    'राजनीति': [
       'https://images.unsplash.com/photo-1541872703-74c5e44368f9?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1529107386315-e1a2ed48a620?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1555848962-6e79363ec58f?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1541872703-74c5e44368f9?q=80&w=1000&auto=format&fit=crop', // Replaced 404
    ],
    'अर्थव्यवस्था': [
       'https://images.unsplash.com/photo-1590283603385-17ffb3a7f29f?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1611974789855-9c2a0a7236a3?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1526304640581-d334cdbbf45e?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1507679799987-c73779587ccf?q=80&w=1000&auto=format&fit=crop',
    ],
    'खेल': [
       'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1517649763962-0c623066013b?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1579952363873-27f3bade9f55?q=80&w=1000&auto=format&fit=crop',
    ],
    'टेक्नोलॉजी': [
       'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1550751827-4bd374c3f58b?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1518770660439-4636190af475?q=80&w=1000&auto=format&fit=crop', // Replaced 404
       'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop',
    ],
    'विश्व': [
       'https://images.unsplash.com/photo-1521295121783-8a321d551ad2?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1451187580459-43490279c0fa?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1496372412473-e8548ffd82bc?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1495020689067-958852a7765e?q=80&w=1000&auto=format&fit=crop',
    ],
    'मनोरंजन': [
       'https://images.unsplash.com/photo-1598899134739-24c46f58b8c0?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1478720568477-152d9b164e26?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1598899134739-24c46f58b8c0?q=80&w=1000&auto=format&fit=crop', // Replaced 404
    ],
    'स्वास्थ्य': [
       'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1532938911079-1b06ac7ceec7?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1579684385127-1ef15d508118?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1499540633125-484965b60031?q=80&w=1000&auto=format&fit=crop',
    ],
    'विज्ञान': [
       'https://images.unsplash.com/photo-1532094349884-543bc11b234d?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1518152006812-edab29b069ac?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1564325724739-bae0bd08762c?q=80&w=1000&auto=format&fit=crop',
       'https://images.unsplash.com/photo-1507413245164-6160d8298b31?q=80&w=1000&auto=format&fit=crop',
    ],
  };

  // ── Cloud Functions callable (singleton, lazily initialised) ───────────────
  static final _getHindiNewsFunction = FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  ).httpsCallable(
    'getHindiNews',
    options: HttpsCallableOptions(
      timeout: const Duration(seconds: 15),
    ),
  );

  Future<Map<String, dynamic>> fetchNews({String? category, String? query, String? page}) async {
    final uiCategory = (category?.isNotEmpty == true) ? category! : 'सभी';
    // Search results bypass the category cache.
    final cacheKey = (query != null && query.isNotEmpty)
        ? 'news_query_${query.hashCode}'
        : 'news_$uiCategory';

    // 1. Return valid cached articles immediately.
    final cached = await _getCachedArticles(cacheKey);
    if (cached != null) {
      return {'articles': cached, 'nextPage': null};
    }

    // 2. No valid cache — fetch fresh data via Cloud Function proxy.
    return _fetchFreshNews(uiCategory, cacheKey, query: query);
  }

  /// Fetches fresh RSS XML from the Cloud Function proxy (getHindiNews).
  ///
  /// The Cloud Function caches responses server-side for 10 minutes, so only
  /// ONE real HTTP call reaches BBC/Bing per 10-minute window across ALL users.
  /// Falls back to direct HTTP if the Cloud Function itself is unavailable.
  Future<Map<String, dynamic>> _fetchFreshNews(
    String uiCategory,
    String cacheKey, {
    String? query,
  }) async {
    // ── STEP 1: Try Cloud Function proxy ─────────────────────────────────────
    try {
      debugPrint('[NewsService] Calling CF getHindiNews for "$uiCategory"...');
      final result = await _getHindiNewsFunction.call(<String, dynamic>{
        'category': uiCategory,
        if (query != null && query.isNotEmpty) 'query': query,
      });
      final xml    = result.data['xml'] as String? ?? '';
      final source = result.data['source'] as String? ?? 'unknown';
      debugPrint('[NewsService] CF getHindiNews source: $source');

      if (xml.isNotEmpty && xml != '<rss/>') {
        // Determine whether the CF returned BBC or Bing XML and parse accordingly.
        final parsed = (source == 'bbc' || _rssFeeds.containsKey(uiCategory))
            ? await _parseRSSXml(xml, uiCategory)
            : await _parseBingXml(xml, uiCategory);
        await _setCachedArticles(cacheKey, parsed);
        return {'articles': parsed, 'nextPage': null};
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('[NewsService] CF getHindiNews error (${e.code}): ${e.message}');
    } catch (e) {
      debugPrint('[NewsService] CF getHindiNews unexpected error: $e');
    }

    // ── STEP 2: Cloud Function unavailable — direct HTTP fallback ─────────────
    // This path is taken only when the CF itself is down or the user is offline.
    // Under normal conditions this branch is never reached.
    debugPrint('[NewsService] Falling back to direct HTTP for "$uiCategory"...');

    if (_rssFeeds.containsKey(uiCategory)) {
      try {
        final result = await _fetchRSS(_rssFeeds[uiCategory]!, uiCategory);
        final articles = result['articles'] as List<Article>;
        await _setCachedArticles(cacheKey, articles);
        return result;
      } catch (e) {
        debugPrint('[NewsService] Direct BBC RSS failed for $uiCategory: $e');
      }
    }

    final result = await _fetchBingNewsRSS(
      category: uiCategory,
      query: query,
    );
    final articles = result['articles'] as List<Article>;
    await _setCachedArticles(cacheKey, articles);
    return result;
  }

  // ── XML parsing helpers ─────────────────────────────────────────────────────
  // These receive pre-fetched XML string (from CF) and return List<Article>.
  // They mirror the logic inside _fetchRSS / _fetchBingNewsRSS but skip the
  // HTTP call, since the Cloud Function already did that.

  Future<List<Article>> _parseRSSXml(String xml, String category) async {
    try {
      final document = XmlDocument.parse(xml);
      final items    = document.findAllElements('item');
      final Set<String> seen = {};
      final List<Article> parsed = [];

      for (final node in items) {
        final title = node.findElements('title').firstOrNull?.innerText ?? '';
        final link  = node.findElements('link').firstOrNull?.innerText  ?? '';
        if (title.isEmpty || link.isEmpty || seen.contains(link)) continue;
        seen.add(link);

        final description = node.findElements('description').firstOrNull?.innerText ?? '';
        final pubDate     = node.findElements('pubDate').firstOrNull?.innerText    ?? '';
        final cleanDesc   = _cleanDescription(description, title, '');
        final validImages = _categoryImages[category] ?? _categoryImages['सभी']!;
        final fallback    = validImages[title.hashCode.abs() % validImages.length];

        String? rssImage;
        final mc = node.findElements('media:content');
        if (mc.isNotEmpty) {
          rssImage = mc.first.getAttribute('url');
        } else {
          final mt = node.findElements('media:thumbnail');
          if (mt.isNotEmpty) {
            rssImage = mt.first.getAttribute('url');
          } else {
            rssImage = _extractImageFromDescription(description);
          }
        }
        final validatedImage = _validateRssImage(rssImage);
        final finalImage = _getImageFromTitleAndFallback(
            title, validatedImage ?? fallback, category);

        parsed.add(Article(
          id:          md5.convert(utf8.encode(link)).toString(),
          title:       title,
          subtitle:    cleanDesc,
          category:    category,
          author:      _determineSource(_rssFeeds[category] ?? ''),
          authorBio:   'विश्वसनीय समाचार स्रोत',
          authorImage: 'https://ui-avatars.com/api/?name='
              '${Uri.encodeComponent(_determineSource(_rssFeeds[category] ?? ""))}&background=random',
          date:        pubDate,
          readTime:    '3 मिनट',
          image:       finalImage,
          url:         link,
          content:     [cleanDesc],
          isPremium:   false,
        ));
      }

      return parsed;
    } catch (e) {
      debugPrint('[NewsService] _parseRSSXml error: $e');
      return [];
    }
  }

  Future<List<Article>> _parseBingXml(String xml, String? category) async {
    try {
      final document = XmlDocument.parse(xml);
      final items    = document.findAllElements('item');
      final List<Future<Article?>> futures = items.map<Future<Article?>>((node) async {
        final title       = node.findElements('title').firstOrNull?.innerText ?? '';
        final link        = node.findElements('link').firstOrNull?.innerText  ?? '';
        final description = node.findElements('description').firstOrNull?.innerText ?? '';
        final source      = node.findElements('source').firstOrNull?.innerText      ?? 'News';
        final pubDate     = node.findElements('pubDate').firstOrNull?.innerText     ?? '';

        String cleanTitle = title.contains(' - ')
            ? title.substring(0, title.lastIndexOf(' - '))
            : title;

        String actualLink = link;
        final bingUri = Uri.tryParse(link);
        if (bingUri != null && bingUri.queryParameters.containsKey('url')) {
          actualLink = bingUri.queryParameters['url'] ?? link;
        }

        final validImages  = _categoryImages[category] ?? _categoryImages['सभी']!;
        final fallback     = validImages[title.hashCode.abs() % validImages.length];
        String? bingImage;
        for (final el in node.children) {
          if (el is XmlElement && el.name.local == 'Image') {
            bingImage = el.innerText;
            break;
          }
        }
        final rawThumb   = bingImage ?? _extractImageFromDescription(description);
        final validated  = _validateRssImage(rawThumb);
        final finalImage = _getImageFromTitleAndFallback(
            cleanTitle, validated ?? fallback, category);

        return Article(
          id:         md5.convert(utf8.encode(actualLink)).toString(),
          title:      cleanTitle,
          subtitle:   _cleanDescription(description, cleanTitle, source),
          category:   category ?? 'समाचार',
          author:     source,
          authorBio:  'स्रोत: $source',
          authorImage: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(source)}&background=random',
          date:       pubDate,
          readTime:   '3 मिनट',
          image:      finalImage,
          url:        actualLink,
          content:    [_cleanDescription(description, cleanTitle, source)],
          isPremium:  false,
        );
      }).toList();

      final results = await Future.wait(futures);
      return results.whereType<Article>().toList();
    } catch (e) {
      debugPrint('[NewsService] _parseBingXml error: $e');
      return [];
    }
  }

  /// Validates an RSS image URL — rejects tracking pixels and placeholders.
  String? _validateRssImage(String? url) {
    if (url == null || !url.startsWith('http')) return null;
    if (url.contains('blank.gif') ||
        url.contains('1x1') ||
        url.contains('placeholder') ||
        url.contains('googlelogo')) return null;
    if (url.length < 50 && !url.contains('th.bing.com')) return null;
    return url;
  }
  
  /// Fetch news for a list of categories in controlled batches.
  ///
  /// Instead of firing all requests simultaneously (which overwhelms the
  /// network on Indian 4G and risks Bing rate-limiting), we process categories
  /// in groups of [_batchSize] with a short pause between batches.
  static const int _batchSize = 3;
  static const Duration _batchDelay = Duration(milliseconds: 300);

  Future<Map<String, List<Article>>> fetchAllCategoriesNews(List<String> categories) async {
    final results = <String, List<Article>>{};

    try {
      for (int i = 0; i < categories.length; i += _batchSize) {
        final batch = categories.skip(i).take(_batchSize).toList();

        // Fire up to _batchSize requests concurrently.
        final futures = batch.map((c) => fetchNews(category: c)).toList();
        final responses = await Future.wait(
          futures,
          eagerError: false, // Don't abort the whole batch on one failure.
        );

        for (int j = 0; j < batch.length; j++) {
          try {
            results[batch[j]] = responses[j]['articles'] as List<Article>;
          } catch (e) {
            debugPrint('[NewsService] Error extracting articles for ${batch[j]}: $e');
            results[batch[j]] = [];
          }
        }

        // Brief pause between batches to avoid flooding the network.
        if (i + _batchSize < categories.length) {
          await Future.delayed(_batchDelay);
        }
      }
    } catch (e) {
      debugPrint('[NewsService] fetchAllCategoriesNews error: $e');
    }

    return results;
  }

  Future<Map<String, dynamic>> _fetchRSS(String url, String category) async {
    final response = await ApiService.get(
      url,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'application/rss+xml, application/xml, text/xml, */*',
      },
      timeout: _httpTimeout,
    );

    if (response != null && response.statusCode == 200) {
      try {
        String body = utf8.decode(response.bodyBytes, allowMalformed: true);
        final document = XmlDocument.parse(body);
        final items = document.findAllElements('item');
      
        final Set<String> seenLinks = {};
        final List<Future<Article?>> articleFutures = [];

        for (var node in items) {
          final title = node.findElements('title').first.innerText;
          final link = node.findElements('link').first.innerText;
          
          if (seenLinks.contains(link)) continue;
          seenLinks.add(link);

          final description = node.findElements('description').isNotEmpty 
              ? node.findElements('description').first.innerText 
              : '';
          
          String pubDate = '';
          if (node.findElements('pubDate').isNotEmpty) {
            pubDate = node.findElements('pubDate').first.innerText;
          }

          final String cleanDesc = _cleanDescription(description, title, '');
          int imgIndex = title.hashCode.abs();
          List<String> validImages = _categoryImages[category] ?? _categoryImages['सभी']!;
          String fallbackImage = validImages[imgIndex % validImages.length];

          // Extract RSS-level image
          String? rssImage;
          final mediaContent = node.findElements('media:content');
          if (mediaContent.isNotEmpty) {
            rssImage = mediaContent.first.getAttribute('url');
          } else {
            final mediaThumbnail = node.findElements('media:thumbnail');
            if (mediaThumbnail.isNotEmpty) {
              rssImage = mediaThumbnail.first.getAttribute('url');
            } else {
              final enclosure = node.findElements('enclosure');
              if (enclosure.isNotEmpty && (enclosure.first.getAttribute('type')?.startsWith('image') ?? false)) {
                rssImage = enclosure.first.getAttribute('url');
              } else {
                rssImage = _extractImageFromDescription(description);
              }
            }
          }

          final String capturedLink = link;
          final String capturedTitle = title;
          
          // Validate extracted RSS image - check for known bad patterns
          String? validatedRssImage;
          if (rssImage != null && rssImage.startsWith('http')) {
            // Reject tracking pixels and common placeholder images
            if (!rssImage.contains('blank.gif') && 
                !rssImage.contains('1x1') &&
                !rssImage.contains('placeholder') &&
                !rssImage.contains('googlelogo') &&
                (rssImage.length > 50 || rssImage.contains('th.bing.com'))) { 
              validatedRssImage = rssImage;
            }
          }

          // Replace bad RSS thumbnails (like just the logo) with content-relevant ones immediately
          // by matching keywords in the article title.
          final String finalImage = _getImageFromTitleAndFallback(capturedTitle, validatedRssImage ?? fallbackImage, category);

          articleFutures.add(() async {
            return Article(
              id: md5.convert(utf8.encode(capturedLink)).toString(),
              title: capturedTitle,
              subtitle: cleanDesc,
              category: category,
              author: _determineSource(url),
              authorBio: 'विश्वसनीय समाचार स्रोत',
              authorImage: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(_determineSource(url))}&background=random',
              date: pubDate,
              readTime: '3 मिनट',
              image: finalImage,
              url: capturedLink,
              content: [cleanDesc],
              isPremium: false,
            );
          }());
        }

        final results = await Future.wait(articleFutures);
        final articles = results.whereType<Article>().toList();
        return {'articles': articles, 'nextPage': null};
      } catch (e, st) {
        debugPrint('[NewsService] Error parsing RSS XML: $e');
        debugPrint('[NewsService] $st');
        throw Exception('Failed to parse RSS: $e');
      }
    } else {
      throw Exception('Failed to load RSS: status ${response?.statusCode}');
    }
  }

  String _determineSource(String url) {
    if (url.contains('bbc.co.uk')) return 'BBC News हिंदी';
    if (url.contains('ndtv.in')) return 'NDTV India';
    if (url.contains('jagran.com')) return 'दैनिक जागरण';
    if (url.contains('news18.com')) return 'News18 Hindi';
    if (url.contains('bhaskar.com')) return 'दैनिक भास्कर';
    if (url.contains('amarujala.com')) return 'अमर उजाला';
    return 'News Source';
  }

  Future<Map<String, dynamic>> _fetchBingNewsRSS({String? category, String? query}) async {
      String url = 'https://www.bing.com/news/search?q=india+news&format=rss&mkt=hi-in';
      
      if (query != null && query.isNotEmpty) {
        url = 'https://www.bing.com/news/search?q=${Uri.encodeComponent(query)}&format=rss&mkt=hi-in';
      } else if (category != null && category != 'सभी') {
        String queryStr = category;
        if (category == 'विश्व') {
          queryStr = 'अंतरराष्ट्रीय'; // International news instead of "World Cup/Sports"
        } else if (category == 'मनोरंजन') {
          queryStr = 'मनोरंजन बॉलीवुड'; // Specific query for better entertainment news
        } else if (category != 'टेक्नोलॉजी') {
          queryStr += " india";
        }
        url = 'https://www.bing.com/news/search?q=${Uri.encodeComponent(queryStr)}&format=rss&mkt=hi-in';
      }

      try {
        final response = await ApiService.get(
          url,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          },
          timeout: _httpTimeout,
        );
        if (response != null && response.statusCode == 200) {
          String body = utf8.decode(response.bodyBytes, allowMalformed: true);
          final document = XmlDocument.parse(body);
          final items = document.findAllElements('item');
          final List<Article> articles = [];
          
          final List<Future<Article?>> articleFutures = items.map<Future<Article?>>((node) async {
             final title = node.findElements('title').first.innerText;
             final link = node.findElements('link').first.innerText;
             final description = node.findElements('description').isNotEmpty ? node.findElements('description').first.innerText : '';
             final source = node.findElements('source').isNotEmpty ? node.findElements('source').first.innerText : 'News';
             
             String cleanTitle = title;
             if (title.contains(' - ')) {
                cleanTitle = title.substring(0, title.lastIndexOf(' - '));
             }

             // Extract the direct URL from Bing's apiclick.aspx wrapper
             String actualLink = link;
             var bingUri = Uri.tryParse(link);
             if (bingUri != null && bingUri.queryParameters.containsKey('url')) {
                 actualLink = bingUri.queryParameters['url'] ?? link;
             }

             int imgIndex = title.hashCode.abs();
             List<String> validImages = _categoryImages[category] ?? _categoryImages['सभी']!;
             String fallbackImage = validImages[imgIndex % validImages.length];

             String? bingImage;
             for (var element in node.children) {
               if (element is XmlElement && element.name.local == 'Image') {
                 bingImage = element.innerText;
                 break;
               }
             }

             String? rssThumb = bingImage ?? _extractImageFromDescription(description);
             // Validate extracted image URL - reject tracking pixels and placeholders
             String? validatedThumb;
             if (rssThumb != null && rssThumb.startsWith('http')) {
               if (!rssThumb.contains('blank.gif') && 
                   !rssThumb.contains('1x1') &&
                   !rssThumb.contains('placeholder') &&
                   !rssThumb.contains('googlelogo') &&
                   (rssThumb.length > 50 || rssThumb.contains('th.bing.com'))) { 
                 validatedThumb = rssThumb;
               }
             }
             String finalImage = _getImageFromTitleAndFallback(cleanTitle, validatedThumb ?? fallbackImage, category);

             String pubDate = node.findElements('pubDate').isNotEmpty ? node.findElements('pubDate').first.innerText : '';

             return Article(
                id: md5.convert(utf8.encode(actualLink)).toString(),
                title: cleanTitle,
                subtitle: _cleanDescription(description, cleanTitle, source),
                category: category ?? 'समाचार',
                author: source,
                authorBio: 'स्रोत: $source',
                authorImage: 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(source)}&background=random',
                date: pubDate,
                readTime: '3 मिनट',
                image: finalImage,
                url: actualLink,
                content: [_cleanDescription(description, cleanTitle, source)],
                isPremium: false,
             );
          }).toList();
          
          final results = await Future.wait(articleFutures);
          articles.addAll(results.whereType<Article>());
          return {'articles': articles, 'nextPage': null};
        }
      } catch (e, st) {
        debugPrint('[NewsService] Bing RSS Error: $e');
        debugPrint('[NewsService] $st');
      }
      return {'articles': <Article>[], 'nextPage': null};
  }


  String _cleanDescription(String htmlString, String title, String source) {
    if (htmlString.isEmpty) return '';
    try {
      final document = html_parser.parse(htmlString);
      String text = document.body?.text ?? '';
      
      // Remove Google News boilerplate phrases first
      final junkPhrases = [
        'View full coverage on Google News',
        'Google News',
        'More news',
        'Top stories',
        'All news',
        'Team coverage',
        'Subscribe',
      ];
      
      for (var phrase in junkPhrases) {
        text = text.replaceAll(RegExp(phrase, caseSensitive: false), '');
      }

      // Clean up whitespace
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      // Remove "Source" if it's at the very beginning
      if (text.startsWith(source)) {
        text = text.substring(source.length).trim();
      }

      // Remove "Title" if it's at the very beginning
      if (text.startsWith(title)) {
        text = text.substring(title.length).trim();
      }
      
      // Remove " - Source" or similar patterns if they remain at start
      if (text.startsWith('- $source')) {
         text = text.substring(source.length + 2).trim();
      }

      // Remove starting punctuation and dashes
      text = text.replaceAll(RegExp(r'^[\-\.,\s]+'), '').trim();

      // If the resulting text is just the source domain (e.g., republicbharat.com), it's not useful
      if (text.toLowerCase() == source.toLowerCase() || 
          text.toLowerCase() == source.replaceAll('.com', '').toLowerCase()) {
        return '';
      }

      return text;
    } catch (e) {
      RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
      return htmlString.replaceAll(exp, '').trim();
    }
  }

  String? _extractImageFromDescription(String description) {
    if (description.isEmpty) return null;
    
    try {
      // Format 1: Standard img src attribute
      RegExp srcExp = RegExp(r'<img[^>]*src="([^"]+)"', caseSensitive: false);
      var srcMatch = srcExp.firstMatch(description);
      if (srcMatch != null) {
        String url = srcMatch.group(1) ?? '';
        if (url.isNotEmpty && url.startsWith('http')) return url;
      }

      // Format 2: img src with single quotes
      RegExp srcExp2 = RegExp(r"<img[^>]*src='([^']+)'", caseSensitive: false);
      var srcMatch2 = srcExp2.firstMatch(description);
      if (srcMatch2 != null) {
        String url = srcMatch2.group(1) ?? '';
        if (url.isNotEmpty && url.startsWith('http')) return url;
      }

      // Format 3: src without quotes (Bing sometimes does this)
      RegExp srcExp3 = RegExp(r'src=([^\s>]+)', caseSensitive: false);
      var srcMatch3 = srcExp3.firstMatch(description);
      if (srcMatch3 != null) {
        String url = srcMatch3.group(1) ?? '';
        // Clean up quotes if present
        url = url.replaceAll('"', '').replaceAll("'", '');
        if (url.isNotEmpty && url.startsWith('http')) return url;
      }

      // Format 4: Look for any URL pattern
      RegExp urlExp = RegExp('https?://[^\\s"<>]+\\.(jpg|jpeg|png|gif|webp)', caseSensitive: false);
      var urlMatch = urlExp.firstMatch(description);
      if (urlMatch != null) {
        return urlMatch.group(0);
      }

      return null;
    } catch (e) {
      return null;
    }
  }


  Future<List<String>> fetchTrendingKeywords() async {
    try {
      // Fetch latest Hindi news
      final newsResult = await fetchNews(category: 'सभी');
      final articles = newsResult['articles'] as List<Article>? ?? [];
      
      if (articles.isEmpty) return ['लोकसभा', 'शेयर बाजार', 'मौसम', 'क्रिकेट', 'बॉलीवुड'];

      Map<String, int> wordCounts = {};
      
      // Extended Hindi stop words
      final stopWords = {
        'में', 'है', 'हैं', 'की', 'के', 'को', 'से', 'ने', 'और', 'पर', 'लिए', 'यह', 'एक', 'का', 'भी', 'क्या',
        'नहीं', 'साथ', 'कर', 'हो', 'गया', 'गई', 'रहे', 'रही', 'वाले', 'वाली', 'तो', 'तक', 'अपने', 'अब',
        'कहा', 'हुई', 'हुए', 'बाद', 'बताएं', 'कैसे', 'क्यों', 'जब', 'तब', 'यहां', 'वहां', 'करते', 'करता',
        'करना', 'करने', 'दे', 'दी', 'देने', 'ले', 'ली', 'लेने', 'जा', 'जी', 'जाने', 'आ', 'आयें', 'होगा',
        'होगी', 'होंगे', 'लिस्ट', 'वाला', 'उन', 'इन', 'इस', 'उस', 'उनका', 'इनका', 'उनको', 'इनको',
        'उन्हें', 'इन्हें', 'उनके', 'इनके', 'उनकी', 'इनकी', 'कि', 'ये', 'वो', 'वे', 'जिस', 'जिन', 'तथा', 
        'या', 'अथवा', 'किन्तु', 'परन्तु', 'लेकिन', 'मगर', 'व', 'बल्कि', 'अत', 'चूंकि', 'क्योंकि', 'ताकि',
        'कोई', 'कुछ', 'कौन', 'किस', 'कहाँ', 'कब', 'किधर', 'कैसा', 'कैसी', 'गए', 'हुवा', 'सकते', 'सकता', 'सकती',
        'चाहिए', 'रहा', 'रहते', 'रहता', 'रहती', 'दिया', 'दिए', 'लिया', 'लये', 'गये', 'ना', 'नी', 'नु',
        'जानिए', 'जानें', 'जानिये', 'होती', 'होता', 'होते', 'लेकर', 'किया', 'दिखा', 'मिले', 'मिलेगा', 
        'बड़ी', 'बड़ा', 'देखें', 'पढ़ें', 'खबर', 'समाचार', 'अपडेट', 'आज', 'कल', 'सिर्फ', 'होने',
        'था', 'थी', 'थे', 'हुआ', 'हुई', 'हुए', 'गयी', 'गये', 'अपना', 'अपनी', 'अपने', 'ही', 'सी', 'सा', 'से',
        'होकर', 'देकर', 'करें', 'करेंगे', 'करेंगी', 'न', 'मत', 'सब', 'सभी', 'कई', 'हर', 'बहुत', 'कम', 'ज्यादा',
        'अधिक', 'ऐसा', 'ऐसी', 'ऐसे', 'वैसा', 'वैसी', 'वैसे', 'चलो', 'चला', 'चले', 'चली', 'किए', 'किये', 'जाएं', 'जाएँ',
        'जाएगा', 'जाएगी', 'जाएंगे', 'करेगा', 'करेगी', 'रहेंगे', 'रहेंगी', 'रहेगा', 'होनी', 'लगा', 'लगी', 'लगे',
        'आया', 'आए', 'आई', 'बना', 'बनी', 'बने', 'बिना', 'अंदर', 'बाहर', 'ऊपर', 'नीचे', 'पीछे', 'आगे', 'पास', 'दूर',
        'सामने', 'बारे', 'द्वारा', 'तरह', 'तरीके', 'कारण', 'वजह', 'जगह', 'समय', 'दिन', 'महीने', 'साल', 'वर्ष',
        'बार', 'बजकर', 'बजे', 'करो', 'मेरी', 'मेरा', 'मेरे', 'मुझे', 'मुझको', 'हम', 'हमारी', 'हमारा', 'हमारे',
        'हमें', 'तुम', 'तुम्हारी', 'तुम्हारा', 'तुम्हारे', 'तुम्हें', 'आप', 'आपकी', 'आपका', 'आपके', 'आपको', 
        'इसके', 'जिसके', 'जिससे', 'जिसको', 'जिसका', 'उसका', 'उसकी', 'उसके', 'उसको', 'उससे', 'जिसमें', 'उसमें',
        'इसमें', 'इनमें', 'उनमें', 'जिनमें', 'इनसे', 'उनसे', 'जिनसे', 'इसलिए', 'तभी', 'यही', 'वही', 'कभी', 'अभी',
        'न्यूज़', 'ताजा', 'ताज़ा', 'ख़बर', 'लाइव', 'ब्रेकिंग', 'न्यूज', 'फोटो', 'वीडियो', 'देखा', 'देखे', 'देखी',
        'news', 'hindi', 'latest', 'live', 'updates', 'today', 'india', 'daily'
      };

      for (var article in articles) {
        String title = article.title;
        if (title.contains(' - ')) {
          title = title.substring(0, title.lastIndexOf(' - '));
        }

        // Remove punctuations and normalize
        // Clean title and split into words
        final cleanTitle = title.replaceAll(RegExp(r'[^\w\s\u0900-\u097F]'), ' ').split(RegExp(r'\s+'));
        
        for (var word in cleanTitle) {
          String lowerWord = word.toLowerCase();
          if (lowerWord.length > 2 && !stopWords.contains(lowerWord) && !RegExp(r'^\d+$').hasMatch(lowerWord)) {
            wordCounts[lowerWord] = (wordCounts[lowerWord] ?? 0) + 1;
          }
        }
      }

      var sortedWords = wordCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
        
      // Take top 15 words and then pick 6-8 randomly for variety each time
      List<String> topKeywords = sortedWords.take(15).map((e) => e.key).toList();
      if (topKeywords.length > 7) {
        topKeywords.shuffle();
        return topKeywords.take(7).toList();
      }
      return topKeywords.isNotEmpty ? topKeywords : ['लोकसभा', 'शेयर बाजार', 'मौसम', 'क्रिकेट', 'बॉलीवुड'];
      
    } catch (e) {
      debugPrint('[NewsService] Trend fetch error: $e');
    }
    // Static Fallback if network fails
    return ['लोकसभा', 'शेयर बाजार', 'मौसम', 'क्रिकेट', 'आईपीएल', 'बॉलीवुड'];
  }


  // fetchLocalNews and city fallback images removed.

  // Very fast image assignment based on context. 
  // It detects the topic from the title and uses curated high-res Unsplash photos
  // ONLY IF the provided RSS image is missing or a generic placeholder.
  String _getImageFromTitleAndFallback(String title, String currentUrl, [String? category]) {
    // 1. If we have a perfectly good image URL from the RSS, ALWAYS use it.
    bool isBadUrl = currentUrl.contains('gstatic.com') || 
        currentUrl.contains('google.com/url') || 
        currentUrl.contains('unsplash.com/photo-1477959858617') ||
        currentUrl.contains('unsplash.com/photo-1486325212027') ||
        currentUrl.contains('unsplash.com/photo-1449824913935') ||
        currentUrl.contains('blank.gif') ||
        currentUrl.contains('placeholder') ||
        currentUrl.contains('googlelogo') ||
        currentUrl.contains('1x1') ||
        (currentUrl.length < 50 && !currentUrl.contains('th.bing.com')) ||
        !currentUrl.startsWith('http') ||
        currentUrl.isEmpty;
        
    if (!isBadUrl) {
      return currentUrl; 
    }

    // 2. If the URL is bad/missing, try to find a relevant image based on title keywords
    String lowerTitle = title.toLowerCase();

    // Keywords that should trigger a specific high-quality image
    if (lowerTitle.contains('मौसम') || lowerTitle.contains('गर्मी') || lowerTitle.contains('बारिश') || lowerTitle.contains('तापमान')) {
      return 'https://images.unsplash.com/photo-1561484930-998b6a7b22e8?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Weather
    } else if (lowerTitle.contains('क्रिकेट') || lowerTitle.contains('आईपीएल') || lowerTitle.contains('bcci') || lowerTitle.contains('मैच') || 
               lowerTitle.contains('फुटबॉल') || lowerTitle.contains('फुटबाल') || lowerTitle.contains('हॉकी') || lowerTitle.contains('टेनिस') || 
               lowerTitle.contains('बैडमिंटन') || lowerTitle.contains('वॉलीबॉल') || lowerTitle.contains('बैस्केटबॉल') || lowerTitle.contains('खेल') ||
               lowerTitle.contains('खिलाडी') || lowerTitle.contains('खिलाड़ी') || lowerTitle.contains('जिम्नास्टिक्स') || lowerTitle.contains('एथलेटिक्स') ||
               lowerTitle.contains('दौड़') || lowerTitle.contains('स्टेडियम') || lowerTitle.contains('टूर्नामेंट') || lowerTitle.contains('चैंपियन')) {
      return 'https://images.unsplash.com/photo-1540747913346-19e32fc3e6ed?ixlib=rb-4.0.3&auto=format&fit=crop&w=1615&q=80'; // Cricket/Stadium
    } else if (lowerTitle.contains('चुनाव') || lowerTitle.contains('वोट') || lowerTitle.contains('बीजेपी') || lowerTitle.contains('कांग्रेस') || lowerTitle.contains('सरकार')) {
      return 'https://images.unsplash.com/photo-1541802035414-b84411648a86?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Politics/Crowd
    } else if (lowerTitle.contains('शेयर') || lowerTitle.contains('बाजार') || lowerTitle.contains('सेंसेक्स') || lowerTitle.contains('निफ्टी')) {
      return 'https://images.unsplash.com/photo-1611974789855-9c2a0a2236a0?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Stock Market
    } else if (lowerTitle.contains('पुलिस') || lowerTitle.contains('गिरफ्तार') || lowerTitle.contains('हादसा') || lowerTitle.contains('हत्या') || lowerTitle.contains('अपराध')) {
      return 'https://images.unsplash.com/photo-1555938564-e1b99af13c8e?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Crime/Siren
    } else if (lowerTitle.contains('सोना') || lowerTitle.contains('चांदी') || lowerTitle.contains('कीमत')) {
      return 'https://images.unsplash.com/photo-1610375461246-83bee855ceaa?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Gold/Market
    } else if (lowerTitle.contains('शिक्षा') || lowerTitle.contains('परीक्षा') || lowerTitle.contains('रिजल्ट') || lowerTitle.contains('cbse')) {
      return 'https://images.unsplash.com/photo-1427504494785-3a9ca7044f45?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Education
    } else if (lowerTitle.contains('फिल्म') || lowerTitle.contains('बॉलीवुड') || lowerTitle.contains('सिनेमा') || lowerTitle.contains('एक्टर') || 
               lowerTitle.contains('अभिनेता') || lowerTitle.contains('अभिनेत्री') || lowerTitle.contains('अभिनय') || lowerTitle.contains('फिल्मी') ||
               lowerTitle.contains('मनोरंजन') || lowerTitle.contains('कंसर्ट') || lowerTitle.contains('संगीत') || lowerTitle.contains('गायक') ||
               lowerTitle.contains('वेब सीरीज') || lowerTitle.contains('वेब सीरीज़') || lowerTitle.contains('ट्रेलर') || lowerTitle.contains('रिलीज')) {
      return 'https://images.unsplash.com/photo-1598899134739-24c46f58b8c0?ixlib=rb-4.0.3&auto=format&fit=crop&w=1456&q=80'; // Entertainment
    } else if (lowerTitle.contains('शादी') || lowerTitle.contains('बारात') || lowerTitle.contains('विवाह') || lowerTitle.contains('समारोह') || lowerTitle.contains('दुल्हा') || lowerTitle.contains('दुल्हन')) {
      return 'https://images.unsplash.com/photo-1583344643039-38cedd9d4d54?ixlib=rb-4.0.3&auto=format&fit=crop&w=1470&q=80'; // Indian Wedding/Tradition
    } else if (lowerTitle.contains('धर्म') || lowerTitle.contains('मंदिर') || lowerTitle.contains('पूजा') || lowerTitle.contains('श्रद्धा') || lowerTitle.contains('फेस्टिवल') || lowerTitle.contains('त्यौहार')) {
      return 'https://images.unsplash.com/photo-1561361513-2d000a50f0dc?ixlib=rb-4.0.3&auto=format&fit=crop&w=1476&q=80'; // Temple/Religion
    } else if (lowerTitle.contains('विश्व') || lowerTitle.contains('दुनिया') || lowerTitle.contains('अंतरराष्ट्रीय') || lowerTitle.contains('विदेश') ||
               lowerTitle.contains('अमेरिका') || lowerTitle.contains('दक्षिण कोरिया') || lowerTitle.contains('जापान') || lowerTitle.contains('चीन') ||
               lowerTitle.contains('यूरोप') || lowerTitle.contains('अफ्रीका') || lowerTitle.contains('एशिया') || lowerTitle.contains('ब्रिटेन') ||
               lowerTitle.contains('फ्रांस') || lowerTitle.contains('जर्मनी') || lowerTitle.contains('रूस') || lowerTitle.contains('संयुक्त राष्ट्र')) {
      return 'https://images.unsplash.com/photo-1521295121783-8a321d551ad2?q=80&w=1000&auto=format&fit=crop'; // World News
    }

    // 3. Fallback logic for generic google news proxy images or city fallbacks
    // Use category-specific fallback images if available
    if (category != null && _categoryImages.containsKey(category)) {
      final categoryImages = _categoryImages[category]!;
      final rand = title.hashCode.abs() % categoryImages.length;
      return categoryImages[rand];
    }
    
    // Generic fallback if no category
    final generalImages = _categoryImages['सभी']!;
    final generalRand = title.hashCode.abs() % generalImages.length;
    return generalImages[generalRand];
  }
}

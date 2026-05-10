import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

class ContentExtractionService {

  /// Fetches the og:image (or twitter:image) from an article URL.
  /// Returns null if unreachable or not found.
  static Future<String?> extractOgImage(String url) async {
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final document = parser.parse(response.body);

        // 1. og:image
        final ogImage = document.querySelector('meta[property="og:image"]');
        final ogUrl = ogImage?.attributes['content']?.trim();
        if (ogUrl != null && ogUrl.startsWith('http')) return ogUrl;

        // 2. twitter:image
        final twImage = document.querySelector('meta[name="twitter:image"]');
        final twUrl = twImage?.attributes['content']?.trim();
        if (twUrl != null && twUrl.startsWith('http')) return twUrl;

        // 3. First large <img> in the page body  
        final imgs = document.querySelectorAll('img[src]');
        for (final img in imgs) {
          final src = img.attributes['src'] ?? '';
          final w = int.tryParse(img.attributes['width'] ?? '') ?? 0;
          final h = int.tryParse(img.attributes['height'] ?? '') ?? 0;
          if (src.startsWith('http') && (w > 200 || h > 150 || (w == 0 && h == 0 && src.contains('jpg')))) {
            return src;
          }
        }
      }
    } catch (_) {
      // Silently fail — caller will use fallback
    }
    return null;
  }

  Future<Map<String, String>?> extractFullContent(String url) async {
    try {
      final client = http.Client();
      
      // Step 1: Initial fetch (handles HTTP 301/302 automatically)
      var request = http.Request('GET', Uri.parse(url));
      request.headers.addAll({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml',
      });
      request.followRedirects = true;

      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 10));
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        String bodyText = response.body;

        // We must parse this to get the *real* publisher URL.
        final metaRefreshExp = RegExp('content=["\']0;\\s*url=(https?://[^"\']+)["\']', caseSensitive: false);
        final match = metaRefreshExp.firstMatch(bodyText);
        
        if (match != null && match.groupCount >= 1) {
          final realUrl = match.group(1)!;
          // Fetch the actual publisher page
          final realReq = http.Request('GET', Uri.parse(realUrl));
          realReq.headers.addAll({
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          });
          final realStream = await client.send(realReq).timeout(const Duration(seconds: 10));
          response = await http.Response.fromStream(realStream);
          bodyText = response.body;
        }

        var document = parser.parse(bodyText);
        
        // --- 1. Extract the True Image ---
        String extractedImage = '';
        final ogImage = document.querySelector('meta[property="og:image"]');
        if (ogImage != null) {
           extractedImage = ogImage.attributes['content'] ?? '';
        } 
        if (extractedImage.isEmpty) {
           final schemaImage = document.querySelector('meta[itemprop="image"]');
           if (schemaImage != null) {
              extractedImage = schemaImage.attributes['content'] ?? '';
           }
        }
        
        // Remove unwanted elements before extracting text
        _removeUnwantedElements(document);

        // --- 2. Extract the Content ---
        dom.Element? mainContent;
        
        List<String> selectors = [
          '.story-details',
          '.text-formatted',
          '.field--name-body',
          '.story__content',
          '.story-full-content',
          '#fullstory',
          '.oi-article-content',
          '.js-oi-article-content',
          '.article-desc',
          '.article-block',
          '.article-body', 
          '#storyBody',
          '.story-body',
          '.post-content', 
          '.entry-content', 
          '.content',
          '#article-content',
          '.post-body',
          '.article-content',
          '.article_body',
          'article', 
          'main', 
        ];


        for (var selector in selectors) {
          mainContent = document.querySelector(selector);
          if (mainContent != null) break;
        }

        // Fallback: If no common container found, look for long paragraphs
        mainContent ??= _findBestContentElement(document.body);

        String contentText = '';
        if (mainContent != null) {
          var paragraphs = mainContent.querySelectorAll('p, .paragraph, p.text');
          if (paragraphs.isNotEmpty) {
            contentText = paragraphs
                .map((p) => p.text.trim())
                .where((text) => text.length > 20)
                .join('\n\n');
          } else {
             contentText = mainContent.text.trim();
          }
        }
        
        return {
           'content': contentText,
           'image': extractedImage,
        };
      }
    } catch (e) {
      print('Error extracting content: $e');
    }
    return null;
  }

  void _removeUnwantedElements(dom.Document document) {
    List<String> toRemove = [
      'script', 'style', 'nav', 'header', 'footer', 'aside', 
      '.ads', '.advertisement', '.social-share', '.comments',
      '.related-posts', '.newsletter-signup', 'iframe', 'ins'
    ];
    for (var selector in toRemove) {
      document.querySelectorAll(selector).forEach((el) => el.remove());
    }
  }

  dom.Element? _findBestContentElement(dom.Element? root) {
    if (root == null) return null;
    
    dom.Element? bestElement;
    int maxScore = 0;

    root.querySelectorAll('*').forEach((element) {
      int score = 0;
      var text = element.text.trim();
      if (text.length > 100) {
        // Simple scoring based on paragraph count and text length
        score = element.querySelectorAll('p').length * 10 + (text.length ~/ 100);
        if (score > maxScore) {
          maxScore = score;
          bestElement = element;
        }
      }
    });

    return bestElement;
  }
}

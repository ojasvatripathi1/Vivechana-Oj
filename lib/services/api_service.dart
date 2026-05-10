import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_performance/firebase_performance.dart';
import '../utils/logger.dart';

class ApiService {
  ApiService._();

  /// Makes an HTTP GET request with performance monitoring, retry logic, and error tracking.
  static Future<http.Response?> get(
    String url, {
    Map<String, String>? headers,
    int maxRetries = 2,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final uri = Uri.parse(url);
    final HttpMetric metric = FirebasePerformance.instance.newHttpMetric(
      url,
      HttpMethod.Get,
    );

    await metric.start();
    
    int attempt = 0;
    while (attempt <= maxRetries) {
      try {
        AppLogger.info('GET Request -> $url (Attempt ${attempt + 1})', tag: 'API');
        
        final response = await http.get(uri, headers: headers).timeout(timeout);
        
        metric.httpResponseCode = response.statusCode;
        metric.responsePayloadSize = response.bodyBytes.length;
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          AppLogger.info('GET Success -> $url [${response.statusCode}]', tag: 'API');
          await metric.stop();
          return response;
        } else {
          AppLogger.warning('GET Failed -> $url [${response.statusCode}]: ${response.body}', tag: 'API');
          if (attempt == maxRetries) {
            _reportApiError(url, 'Status Code: ${response.statusCode}', response.body);
          }
        }
      } catch (e, stackTrace) {
        AppLogger.warning('GET Exception -> $url: $e', tag: 'API');
        if (attempt == maxRetries) {
          _reportApiError(url, 'Exception', e, stackTrace);
          metric.httpResponseCode = 0; // Indicate network/timeout failure
        }
      }
      
      attempt++;
      if (attempt <= maxRetries) {
        // Exponential backoff
        await Future.delayed(Duration(seconds: 2 * attempt));
      }
    }

    await metric.stop();
    return null; // Return null if all retries fail
  }

  static void _reportApiError(String url, String type, dynamic error, [StackTrace? stackTrace]) {
    AppLogger.error(
      'API Error [$type] on $url',
      tag: 'API',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

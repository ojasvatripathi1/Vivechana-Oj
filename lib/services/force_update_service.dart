import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ForceUpdateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns true if the currently installed app version is below the minimum
  /// required version stored in Firestore at `app_config/version`.
  ///
  /// Firestore document structure:
  /// ```
  /// app_config/version {
  ///   minVersionCode: 5,          // Android versionCode (the +N in pubspec.yaml)
  ///   playStoreUrl: "https://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj"
  /// }
  /// ```
  Future<ForceUpdateResult> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      debugPrint('ForceUpdate: current versionCode = $currentVersionCode');

      final doc = await _db.collection('app_config').doc('version').get();

      if (!doc.exists) {
        debugPrint('ForceUpdate: app_config/version doc not found — skipping check');
        return ForceUpdateResult(updateRequired: false);
      }

      final data = doc.data()!;
      final minVersionCode = (data['minVersionCode'] as num?)?.toInt() ?? 0;
      final playStoreUrl = data['playStoreUrl'] as String? ??
          'https://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj';

      debugPrint('ForceUpdate: minVersionCode = $minVersionCode');

      if (currentVersionCode < minVersionCode) {
        return ForceUpdateResult(
          updateRequired: true,
          playStoreUrl: playStoreUrl,
        );
      }

      return ForceUpdateResult(updateRequired: false);
    } catch (e) {
      // On any error (no network, Firestore down), allow the user through.
      // Better UX than blocking the app for a network hiccup.
      debugPrint('ForceUpdate check failed: $e — allowing user through');
      return ForceUpdateResult(updateRequired: false);
    }
  }
}

class ForceUpdateResult {
  final bool updateRequired;
  final String playStoreUrl;

  const ForceUpdateResult({
    required this.updateRequired,
    this.playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj',
  });
}

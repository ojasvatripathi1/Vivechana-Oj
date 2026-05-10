// bin/set_min_version.dart
// Run with: dart run bin/set_min_version.dart
// Sets the Firestore app_config/version document to force users
// on versionCode < 11 to update from the Play Store.

import 'dart:io';

void main() async {
  // We use the Firebase Admin REST API via the firebase CLI to update the doc.
  // Since we can't import firebase_admin in a bin script easily, we use the
  // firebase firestore:set command instead.
  print('Updating Firestore app_config/version with minVersionCode = 11...');
  final result = await Process.run(
    'firebase',
    [
      'firestore:set',
      'app_config/version',
      '--data',
      '{"minVersionCode": 11, "playStoreUrl": "https://play.google.com/store/apps/details?id=com.vivechanaoj.vivechana_oj"}',
    ],
    workingDirectory: Directory.current.path,
  );
  print(result.stdout);
  if (result.stderr.toString().isNotEmpty) print('STDERR: ${result.stderr}');
  print('Done. Exit code: ${result.exitCode}');
}

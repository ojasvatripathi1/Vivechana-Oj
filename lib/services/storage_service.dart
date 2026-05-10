import 'dart:io';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';

/// Centralised Firebase Storage helper.
///
/// Features:
///  - **In-app JPEG compression** (quality 80, max 1080×1080) via
///    flutter_image_compress so uploads are exceptionally light (< 1 MB).
///  - **Video compression** via video_compress before upload (~5–10× size reduction).
///  - **Exponential backoff retry** (3 attempts: 1s → 2s → 4s) on transient
///    network failures — critical for Indian mobile connections.
///  - Upload / delete helpers for cover images, profile photos, and PDFs.
class StorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instanceFor(
    bucket: 'gs://vivechanaoj-866db.firebasestorage.app',
  );

  /// Maximum number of upload attempts before giving up.
  static const int _maxRetries = 3;

  // ── Upload helpers ──────────────────────────────────────────────────────

  /// Upload a **user profile photo** with compression.
  ///
  /// [storagePath] example: `writer_profiles/<uid>.jpg`
  static Future<String?> uploadProfilePhoto({
    required File file,
    required String storagePath,
  }) async {
    final compressed = await _compressImage(file);
    return _uploadWithRetry(file: compressed ?? file, storagePath: storagePath);
  }

  /// Upload a **magazine cover image** (admin) with compression.
  ///
  /// [storagePath] example: `magazines/covers/<edition-id>.jpg`
  static Future<String?> uploadMagazineCover({
    required File file,
    required String storagePath,
  }) async {
    final compressed = await _compressImage(file);
    return _uploadWithRetry(file: compressed ?? file, storagePath: storagePath);
  }

  /// Upload an **article cover image** with compression.
  ///
  /// [storagePath] example: `article_covers/<article-id>.jpg`
  static Future<String?> uploadArticleCover({
    required File file,
    required String storagePath,
  }) async {
    final compressed = await _compressImage(file);
    return _uploadWithRetry(file: compressed ?? file, storagePath: storagePath);
  }

  /// Upload a **PDF file** (no compression — PDFs must not be re-encoded).
  ///
  /// [storagePath] example: `magazines/pdfs/<edition-id>.pdf`
  static Future<String?> uploadPdf({
    required File file,
    required String storagePath,
  }) async {
    return _uploadRawWithRetry(
      file: file,
      storagePath: storagePath,
      contentType: 'application/pdf',
    );
  }

  /// Upload a **video file** (MP4) to Firebase Storage.
  ///
  /// Compresses the video before upload using video_compress.
  /// Falls back to the original file if compression fails.
  ///
  /// [storagePath] example: `news_reels/<timestamp>.mp4`
  static Future<String?> uploadVideo({
    required File file,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    File fileToUpload = file;

    // Attempt video compression — on failure, fall back to original.
    try {
      debugPrint('[StorageService] Compressing video before upload...');
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      if (info?.file != null) {
        fileToUpload = info!.file!;
        debugPrint(
          '[StorageService] Video compressed: '
          '${(file.lengthSync() / 1048576).toStringAsFixed(1)} MB → '
          '${(fileToUpload.lengthSync() / 1048576).toStringAsFixed(1)} MB',
        );
      }
    } catch (e) {
      debugPrint('[StorageService] Video compression failed, using original: $e');
    }

    return _uploadRawWithRetry(
      file: fileToUpload,
      storagePath: storagePath,
      contentType: 'video/mp4',
      onProgress: onProgress,
    );
  }

  // ── Delete helper ────────────────────────────────────────────────────────

  /// Delete a file from Firebase Storage by its full **download URL**.
  /// Silently ignores errors (e.g. file already gone) so the delete flow
  /// does not break the calling operation.
  static Future<void> deleteByUrl(String downloadUrl) async {
    if (downloadUrl.isEmpty) return;
    try {
      if (!downloadUrl.contains('firebasestorage.googleapis.com') &&
          !downloadUrl.contains('storage.googleapis.com')) {
        debugPrint('[StorageService] Skipping delete — not a Firebase Storage URL');
        return;
      }
      final ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('[StorageService] Deleted: $downloadUrl');
    } catch (e) {
      // File may have already been deleted or the URL may be malformed.
      // Do not rethrow — deletion failure must never block the caller.
      debugPrint('[StorageService] deleteByUrl ignored error: $e');
    }
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  /// Compress an image to max 1080×1080, quality 80.
  /// Returns `null` if compression fails (caller must fall back to original).
  static Future<File?> _compressImage(File file) async {
    try {
      final ext = path.extension(file.path).toLowerCase();
      final format = (ext == '.png') ? CompressFormat.png : CompressFormat.jpeg;
      final outPath = '${file.path}_compressed${ext.isEmpty ? '.jpg' : ext}';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        outPath,
        quality: 80,
        minWidth: 1080,
        minHeight: 1080,
        format: format,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('[StorageService] Image compression failed, using original: $e');
      return null;
    }
  }

  /// Core upload with **exponential backoff retry**.
  ///
  /// Attempts [_maxRetries] times before returning null.
  /// Wait schedule: attempt 1 → 1s, attempt 2 → 2s, attempt 3 → 4s.
  static Future<String?> _uploadWithRetry({
    required File file,
    required String storagePath,
    void Function(double progress)? onProgress,
  }) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        // Always force-refresh the auth token before uploading.
        // Firebase Storage returns 403 when the cached token is stale
        // (e.g. right after phone OTP linking or anonymous sign-in).
        await FirebaseAuth.instance.currentUser?.getIdToken(true);

        final ref = _storage.ref().child(storagePath);
        final uploadTask = ref.putFile(file);

        // Wire up progress tracking if a callback was provided.
        if (onProgress != null) {
          uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0) {
              onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
        }

        final snapshot = await uploadTask;
        final downloadUrl = await snapshot.ref.getDownloadURL();
        debugPrint('[StorageService] Upload succeeded on attempt $attempt: $storagePath');
        return downloadUrl;
      } catch (e) {
        debugPrint('[StorageService] Upload attempt $attempt/$_maxRetries failed ($storagePath): $e');

        if (attempt == _maxRetries) {
          // All retries exhausted — log the final error type for diagnostics.
          if (e is FirebaseException) {
            debugPrint('[StorageService] Final FirebaseException — code: ${e.code}, msg: ${e.message}');
          }
          return null; // Caller handles null gracefully.
        }

        // Exponential backoff: 2^(attempt-1) seconds → 1s, 2s, 4s.
        final backoff = Duration(seconds: pow(2, attempt - 1).toInt());
        debugPrint('[StorageService] Retrying in ${backoff.inSeconds}s...');
        await Future.delayed(backoff);
      }
    }
    return null;
  }

  /// Like [_uploadWithRetry] but explicitly sets the MIME content-type.
  /// Used for PDFs and raw video uploads.
  static Future<String?> _uploadRawWithRetry({
    required File file,
    required String storagePath,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      File? tempFile;
      try {
        // Force-refresh token here too (used for PDF uploads by admins).
        await FirebaseAuth.instance.currentUser?.getIdToken(true);

        final ref = _storage.ref().child(storagePath);
        final metadata = SettableMetadata(contentType: contentType);

        // To bypass Android `file_picker` cache permission issues without
        // causing OutOfMemoryErrors from reading large PDFs into RAM via
        // `readAsBytes`, we copy the file to the system temp directory first.
        tempFile = File(
          '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}_vivechana_temp',
        );
        await file.copy(tempFile.path);

        final uploadTask = ref.putFile(tempFile, metadata);

        if (onProgress != null) {
          uploadTask.snapshotEvents.listen((snapshot) {
            if (snapshot.totalBytes > 0) {
              onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
            }
          });
        }

        final snapshot = await uploadTask;
        final url = await snapshot.ref.getDownloadURL();
        debugPrint('[StorageService] Raw upload succeeded on attempt $attempt: $storagePath');
        return url;
      } catch (e) {
        debugPrint('[StorageService] Raw upload attempt $attempt/$_maxRetries failed ($storagePath): $e');

        if (attempt == _maxRetries) {
          if (e is FirebaseException) {
            debugPrint('[StorageService] Final FirebaseException — code: ${e.code}, msg: ${e.message}');
          }
          return null;
        }

        final backoff = Duration(seconds: pow(2, attempt - 1).toInt());
        debugPrint('[StorageService] Retrying in ${backoff.inSeconds}s...');
        await Future.delayed(backoff);
      } finally {
        // Always clean up the temp file, even if the upload threw.
        if (tempFile != null) {
          try {
            if (await tempFile.exists()) await tempFile.delete();
          } catch (_) {
            // Temp cleanup is best-effort — ignore failures.
          }
        }
      }
    }
    return null;
  }
}

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/magazine_edition.dart';
import 'storage_service.dart';

class MagazineService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore Integration ──────────────────────────────────────────────

  /// Stream of published magazines, ordered by ID descending.
  Stream<List<MagazineEdition>> getMagazinesStream() {
    return _db.collection('magazines').snapshots().map((snapshot) {
      debugPrint('getMagazinesStream: received ${snapshot.docs.length} docs');
      return snapshot.docs
          .map((doc) {
            try {
              return MagazineEdition.fromMap(doc.id, doc.data());
            } catch (e) {
              debugPrint('Error parsing magazine ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MagazineEdition>()
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
    });
  }

  /// Get the single most recent published magazine by ID sequence.
  Future<MagazineEdition?> getLatestMagazine() async {
    try {
      final snap = await _db.collection('magazines').get();
      if (snap.docs.isEmpty) return null;
      final allMags = snap.docs
          .map((doc) {
            try {
              return MagazineEdition.fromMap(doc.id, doc.data());
            } catch (e) {
              debugPrint('Error parsing magazine ${doc.id}: $e');
              return null;
            }
          })
          .whereType<MagazineEdition>()
          .toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      return allMags.first;
    } catch (e) {
      debugPrint('Error fetching latest magazine: $e');
      return null;
    }
  }

  // ── Firebase Storage Upload ────────────────────────────────────────────

  /// Upload a magazine file (cover image or PDF) to Firebase Storage.
  ///
  /// For covers:  stored at `magazines/covers/<timestamp>.jpg`
  /// For PDFs:    stored at `magazines/pdfs/<timestamp>.pdf`
  ///
  /// Returns the download URL or null on failure.
  Future<String?> uploadMagazineFile(File file, {required bool isPdf}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (isPdf) {
        final storagePath = 'magazines/pdfs/$timestamp.pdf';
        return await StorageService.uploadPdf(file: file, storagePath: storagePath);
      } else {
        final storagePath = 'magazines/covers/$timestamp.jpg';
        return await StorageService.uploadMagazineCover(
          file: file,
          storagePath: storagePath,
        );
      }
    } catch (e) {
      debugPrint('[MagazineService] uploadMagazineFile error: $e');
      return null;
    }
  }

  /// Delete a magazine file from Firebase Storage by its download URL.
  Future<bool> _deleteStorageFile(String fileUrl) async {
    try {
      await StorageService.deleteByUrl(fileUrl);
      return true;
    } catch (e) {
      debugPrint('[MagazineService] _deleteStorageFile error: $e');
      return false;
    }
  }

  /// Permanently delete a published magazine (cover + PDF + Firestore doc).
  Future<bool> deleteMagazine(MagazineEdition edition) async {
    try {
      if (edition.coverUrl.isNotEmpty) {
        await _deleteStorageFile(edition.coverUrl);
      }
      if (edition.pdfUrl.isNotEmpty) {
        await _deleteStorageFile(edition.pdfUrl);
      }
      await _db.collection('magazines').doc(edition.id).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting magazine: $e');
      return false;
    }
  }

  /// Publish a new magazine edition to Firestore.
  Future<bool> publishMagazine(MagazineEdition edition) async {
    try {
      await _db.collection('magazines').doc(edition.id).set(edition.toMap());
      return true;
    } catch (e) {
      debugPrint('Error publishing magazine: $e');
      return false;
    }
  }

  /// Update an existing magazine edition in Firestore and optional files in Storage.
  Future<bool> updateMagazine(MagazineEdition edition,
      {File? newCover, File? newPdf}) async {
    try {
      String coverUrl = edition.coverUrl;
      String pdfUrl = edition.pdfUrl;

      if (newCover != null) {
        final uploadedCover =
            await uploadMagazineFile(newCover, isPdf: false);
        if (uploadedCover != null) {
          if (edition.coverUrl.isNotEmpty) {
            await _deleteStorageFile(edition.coverUrl);
          }
          coverUrl = uploadedCover;
        }
      }

      if (newPdf != null) {
        final uploadedPdf = await uploadMagazineFile(newPdf, isPdf: true);
        if (uploadedPdf != null) {
          if (edition.pdfUrl.isNotEmpty) {
            await _deleteStorageFile(edition.pdfUrl);
          }
          pdfUrl = uploadedPdf;
        }
      }

      final updatedEdition = MagazineEdition(
        id: edition.id,
        title: edition.title,
        subtitle: edition.subtitle,
        coverUrl: coverUrl,
        pdfUrl: pdfUrl,
        month: edition.month,
        year: edition.year,
        isLatest: edition.isLatest,
        isUploaded: true,
        pageCount: edition.pageCount,
        highlights: edition.highlights,
      );

      await _db
          .collection('magazines')
          .doc(edition.id)
          .set(updatedEdition.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating magazine: $e');
      return false;
    }
  }

  // ── Access control ─────────────────────────────────────────────────────

  /// All editions are now free — always returns true.
  // ignore: avoid_unused_parameters
  bool canReadEdition(Map<String, dynamic> status, String editionId) => true;

  // ── Membership helpers (kept for backward-compat, not used in UI) ──────

  Future<Map<String, dynamic>> getMembershipStatus(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (!doc.exists) return {'type': 'none', 'isAdmin': false};
      final data = doc.data()!;
      final user = FirebaseAuth.instance.currentUser;
      final bool isAdmin = data['isAdmin'] == true ||
          (user != null && user.email == 'vivechanaoaj@gmail.com');
      return {'type': 'none', 'paidEditions': <String>[], 'isAdmin': isAdmin};
    } catch (_) {
      return {'type': 'none', 'paidEditions': <String>[], 'isAdmin': false};
    }
  }

  Future<void> saveDeliveryAddress(
      String uid, Map<String, String> address) async {
    await _db.collection('users').doc(uid).set({
      'deliveryAddress': address,
    }, SetOptions(merge: true));
  }
}

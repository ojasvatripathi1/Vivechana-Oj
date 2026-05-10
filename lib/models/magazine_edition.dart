import 'package:cloud_firestore/cloud_firestore.dart';

class MagazineEdition {
  final String id;        // e.g. "2025-03"
  final String title;     // "मार्च 2025"
  final String subtitle;  // issue tagline
  final String coverUrl;  // network image URL for magazine cover
  final String pdfUrl;    // URL for the PDF
  final String month;     // Hindi month name
  final int year;
  final bool isLatest;
  final bool isUploaded;  // whether the PDF is actually available
  final int pageCount;
  final List<String> highlights; // featured article titles

  const MagazineEdition({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.pdfUrl,
    required this.month,
    required this.year,
    this.isLatest = false,
    this.isUploaded = false,
    this.pageCount = 48,
    this.highlights = const [],
  });

  factory MagazineEdition.fromMap(String id, Map<String, dynamic> data) {
    return MagazineEdition(
      id: id,
      title: data['title'] ?? '',
      subtitle: data['subtitle'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      pdfUrl: data['pdfUrl'] ?? '',
      month: data['month'] ?? '',
      year: data['year'] ?? 0,
      isLatest: data['isLatest'] ?? false,
      isUploaded: data['isUploaded'] ?? false,
      pageCount: data['pageCount'] ?? 48,
      highlights: List<String>.from(data['highlights'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'coverUrl': coverUrl,
      'pdfUrl': pdfUrl,
      'month': month,
      'year': year,
      'isLatest': isLatest,
      'isUploaded': isUploaded,
      'pageCount': pageCount,
      'highlights': highlights,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

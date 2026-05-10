import 'package:cloud_firestore/cloud_firestore.dart';

enum ReelType { youtube, native }

class NewsReel {
  final String id;
  final String title;
  final ReelType type;
  final String videoUrl; // For native: Firebase Storage MP4 URL. For youtube: video ID or full URL
  final String? thumbnailUrl;
  final DateTime createdAt;

  NewsReel({
    required this.id,
    required this.title,
    required this.type,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory NewsReel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NewsReel(
      id: doc.id,
      title: data['title'] ?? '',
      type: (data['type'] == 'youtube') ? ReelType.youtube : ReelType.native,
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type == ReelType.youtube ? 'youtube' : 'native',
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}

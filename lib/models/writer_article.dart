import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class WriterArticle {
  final String id;
  final String title;
  final String content;
  final String category; // कविता, कहानी, लेख
  final String authorId;
  final String authorName;
  final String? authorImageUrl;
  final String? coverImageUrl;
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'rejected'
  final int views;
  final int likes;

  WriterArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.authorId,
    required this.authorName,
    this.authorImageUrl,
    this.coverImageUrl,
    required this.createdAt,
    this.status = 'pending',
    this.views = 0,
    this.likes = 0,
  });

  /// Extracts plain text from Delta JSON content, or returns raw content for legacy articles.
  String get plainTextContent {
    final trimmed = content.trimLeft();
    if (trimmed.startsWith('[{')) {
      try {
        final List<dynamic> delta = jsonDecode(content);
        final buffer = StringBuffer();
        for (final op in delta) {
          if (op is Map && op['insert'] is String) {
            buffer.write(op['insert']);
          }
        }
        return buffer.toString().trim();
      } catch (_) {
        return content;
      }
    }
    return content;
  }

  factory WriterArticle.fromMap(String id, Map<String, dynamic> data) {
    return WriterArticle(
      id: id,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      category: data['category'] ?? 'लेख',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown Author',
      authorImageUrl: data['authorImageUrl'],
      coverImageUrl: data['coverImageUrl'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      views: data['views'] ?? 0,
      likes: data['likes'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'category': category,
      'authorId': authorId,
      'authorName': authorName,
      'authorImageUrl': authorImageUrl,
      'coverImageUrl': coverImageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'views': views,
      'likes': likes,
    };
  }

  int get readTimeMinutes {
    // Calculate approximate reading time based on 200 words per minute
    final wordCount = plainTextContent.split(RegExp(r'\s+')).length;
    final minutes = (wordCount / 200).ceil();
    return minutes > 0 ? minutes : 1;
  }

  WriterArticle copyWith({
    String? id,
    String? title,
    String? content,
    String? category,
    String? authorId,
    String? authorName,
    String? authorImageUrl,
    String? coverImageUrl,
    DateTime? createdAt,
    String? status,
    int? views,
    int? likes,
  }) {
    return WriterArticle(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorImageUrl: authorImageUrl ?? this.authorImageUrl,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      views: views ?? this.views,
      likes: likes ?? this.likes,
    );
  }
}

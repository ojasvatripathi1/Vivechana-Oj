import 'dart:convert';

class Article {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final String author;
  final String authorBio;
  final String authorImage;
  final String date;
  final String readTime;
  final String image;
  final String url;
  final List<String> content;
  final bool isPremium;

  Article({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.author,
    required this.authorBio,
    required this.authorImage,
    required this.date,
    required this.readTime,
    required this.image,
    required this.url,
    required this.content,
    this.isPremium = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'category': category,
        'author': author,
        'authorBio': authorBio,
        'authorImage': authorImage,
        'date': date,
        'readTime': readTime,
        'image': image,
        'url': url,
        'content': content,
        'isPremium': isPremium,
      };

  factory Article.fromJson(Map<String, dynamic> json) => Article(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        category: json['category'] as String? ?? '',
        author: json['author'] as String? ?? '',
        authorBio: json['authorBio'] as String? ?? '',
        authorImage: json['authorImage'] as String? ?? '',
        date: json['date'] as String? ?? '',
        readTime: json['readTime'] as String? ?? '',
        image: json['image'] as String? ?? '',
        url: json['url'] as String? ?? '',
        content: List<String>.from(json['content'] ?? []),
        isPremium: json['isPremium'] as bool? ?? false,
      );

  /// Encode to a JSON string (for notification payload / SharedPreferences)
  String toJsonString() => jsonEncode(toJson());

  /// Decode from a JSON string
  static Article? fromJsonString(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty) return null;
    try {
      return Article.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}


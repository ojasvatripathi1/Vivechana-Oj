import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';

class SoochnaenPage extends StatelessWidget {
  const SoochnaenPage({super.key});

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return DateFormat('d MMM yyyy, h:mm a', 'hi').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        ),
        title: const Text(
          'सूचनाएँ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('announcements')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryRed),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
                  const SizedBox(height: 12),
                  const Text(
                    'कुछ गड़बड़ हुई। कृपया बाद में प्रयास करें।',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryRed.withOpacity(0.08),
                      ),
                      child: Icon(
                        Icons.notifications_none_rounded,
                        size: 64,
                        color: AppColors.primaryRed.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'कोई सूचना नहीं',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.textPrimaryOn(isDark),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'अभी कोई प्रशासनिक सूचना नहीं है।\nनई सूचनाएँ यहाँ दिखाई देंगी।',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.textSecondaryOn(isDark),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] as String? ?? '';
              final body = data['body'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final postedBy = data['postedBy'] as String? ?? 'प्रशासन';

              return _AnnouncementCard(
                title: title,
                body: body,
                dateStr: _formatDate(createdAt),
                postedBy: postedBy,
                index: index,
              );
            },
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final String title;
  final String body;
  final String dateStr;
  final String postedBy;
  final int index;

  const _AnnouncementCard({
    required this.title,
    required this.body,
    required this.dateStr,
    required this.postedBy,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(Theme.of(context).brightness == Brightness.dark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: index == 0 ? AppColors.primaryRed : AppColors.primaryLight,
            width: 4,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge + Date row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (index == 0 ? AppColors.primaryRed : AppColors.primaryLight)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        size: 13,
                        color: index == 0
                            ? AppColors.primaryRed
                            : AppColors.primaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'प्रशासन सूचना',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: index == 0
                              ? AppColors.primaryRed
                              : AppColors.primaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 10,
                    color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: DesignTokens.textPrimaryOn(Theme.of(context).brightness == Brightness.dark),
                height: 1.3,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                body,
                style: TextStyle(
                  fontSize: 13,
                  color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark),
                  height: 1.55,
                ),
              ),
            ],
            const SizedBox(height: 10),
            // Posted by
            Row(
              children: [
                Icon(Icons.person_outline, size: 13, color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark).withOpacity(0.6)),
                const SizedBox(width: 4),
                Text(
                  postedBy,
                  style: TextStyle(
                    fontSize: 11,
                    color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

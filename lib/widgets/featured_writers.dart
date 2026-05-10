import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import '../constants/app_colors.dart';
import '../pages/writer_profile_page.dart';

class FeaturedWriters extends StatelessWidget {
  const FeaturedWriters({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('status', isEqualTo: 'approved')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Loading ───────────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildShimmerSection(isDark);
        }

        // ── Error ─────────────────────────────────────────────────────
        if (snapshot.hasError) {
          return _buildShimmerSection(isDark);
        }

        // ── Empty ─────────────────────────────────────────────────────
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildShimmerSection(isDark);
        }

        final List<Map<String, String>> writers = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;

          final fullName = data['fullName'] as String? ?? '';
          final penName = data['penName'] as String? ?? '';
          final name = penName.isNotEmpty ? penName : fullName;

          final gender = data['gender'] as String? ?? '';
          final suffix = gender == 'महिला' ? 'लेखिका' : 'लेखक';

          final genres = List<String>.from(data['preferredGenres'] ?? []);
          final designation = suffix;

          final bio = data['bio'] as String? ?? '';
          String quote = bio.trim().replaceAll('\n', ' ');
          if (quote.length > 60) {
            quote = '${quote.substring(0, 57)}...';
          } else if (quote.isEmpty) {
            quote = 'विवेचना-ओज ${gender == 'महिला' ? 'की एक मूल्यवान लेखिका' : 'के एक मूल्यवान लेखक'}।';
          }

          final String rawImage = data['profileImageUrl'] as String? ?? '';
          final image = rawImage.isNotEmpty
              ? rawImage
              : 'https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=9B0B1E&color=fff&size=128&bold=true';

          final uid = data['uid'] as String? ?? doc.id;

          writers.add({
            'name': name,
            'designation': designation,
            'quote': quote,
            'bio': bio,
            'gender': gender,
            'image': image,
            'uid': uid,
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
              child: Text(
                'प्रमुख लेखक',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.primaryLight,
                ),
              ),
            ),
            SizedBox(
              height: 280,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: writers.length,
                itemBuilder: (context, index) {
                  return _buildWriterCard(writers[index], context, isDark);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Shimmer section — preserves same layout height (32 header + 280 list) ──
  Widget _buildShimmerSection(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 22,
              width: 120,
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            itemBuilder: (_, __) => _buildShimmerCard(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerCard(bool isDark) {
    final baseColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;
    final highlightColor = isDark ? Colors.grey.shade700 : Colors.grey.shade100;
    final containerColor = isDark ? Colors.grey.shade900 : Colors.white;
    final blockColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: 185,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar circle
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: containerColor),
            ),
            const SizedBox(height: 12),
            // Name line
            Container(height: 14, width: 100, color: blockColor),
            const SizedBox(height: 8),
            // Designation line
            Container(height: 10, width: 70, color: blockColor),
            const SizedBox(height: 8),
            // Quote lines
            Container(height: 8, width: double.infinity, color: blockColor),
            const SizedBox(height: 4),
            Container(height: 8, width: 120, color: blockColor),
            const SizedBox(height: 16),
            // Button
            Container(
              height: 32,
              width: double.infinity,
              decoration: BoxDecoration(
                  color: blockColor, borderRadius: BorderRadius.circular(20)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWriterCard(Map<String, String> writer, BuildContext context, bool isDark) {
    return FadeInRight(
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WriterProfilePage(writer: writer),
            ),
          );
        },
        child: Container(
          width: 185,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Hero(
                tag: 'writer_image_${writer['name']}',
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primaryRed, width: 2.5),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundImage: NetworkImage(writer['image']!),
                    onBackgroundImageError: (exception, stackTrace) {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                writer['name']!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                writer['designation']!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.redAccent.shade200 : AppColors.primaryRed,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                writer['quote']!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.white54 : Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'प्रोफ़ाइल देखें',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

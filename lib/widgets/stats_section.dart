import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/app_colors.dart';

class CommunityStats extends StatelessWidget {
  const CommunityStats({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      color: AppColors.backgroundLight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn('120+', 'लेखक'),
          _buildDivider(),
          _buildStatColumn('500+', 'प्रकाशित लेख'),
          _buildDivider(),
          _buildStatColumn('15K+', 'मासिक पाठक'),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String value, String label) {
    return FadeIn(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.accentOrange.withOpacity(0.3),
    );
  }
}

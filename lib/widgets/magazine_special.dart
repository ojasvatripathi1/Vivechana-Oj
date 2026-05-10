import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../constants/app_colors.dart';

class MagazineSpecial extends StatefulWidget {
  const MagazineSpecial({super.key});

  @override
  State<MagazineSpecial> createState() => _MagazineSpecialState();
}

class _MagazineSpecialState extends State<MagazineSpecial> with SingleTickerProviderStateMixin {
  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideInUp(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 32),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.magazineGradient,
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -10 * _floatingController.value),
                    child: child,
                  );
                },
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      'https://images.unsplash.com/photo-1544947950-fa07a98d237f?q=80&w=1000&auto=format&fit=crop',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'इस माह की विशेष अंक',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'विचारों की दुनिया में एक नया सफर। इस अंक में पढ़ें कला, संस्कृति और समाज पर विशेष लेख।',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    label: '₹20 में पढ़ें',
                    color: AppColors.accentOrange,
                    isOutline: false,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    label: '₹300 वार्षिक सदस्यता',
                    color: Colors.white,
                    isOutline: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required bool isOutline,
  }) {
    return Container(
      width: double.infinity,
      height: 36,
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : color,
        border: isOutline ? Border.all(color: Colors.white, width: 1.5) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

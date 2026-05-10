import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import 'package:animate_do/animate_do.dart';

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        backgroundColor: DesignTokens.primary,
        title: const Text(
          'हमारे बारे में',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Magazine Logo Section
            FadeInDown(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/vivechana-oj-logo.png',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Magazine Name
            FadeInUp(
              delay: const Duration(milliseconds: 50),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'विवेचना-ओज',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.textPrimaryOn(isDark),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vivechana Oj - विचार और विश्लेषण का मंच',
                      style: TextStyle(
                        fontSize: 14,
                        color: DesignTokens.textSecondaryOn(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // About Section
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: _buildSection(
                title: 'हमारा मिशन',
                content:
                    'विवेचना-ओज एक अग्रणी डिजिटल पत्रिका है जो समकालीन भारत की राजनीति, अर्थव्यवस्था, समाज और संस्कृति पर गहन विश्लेषण प्रस्तुत करती है। हम विश्वास करते हैं कि सूचना की शक्ति से ही एक जागरूक और सशक्त समाज का निर्माण संभव है।',
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 24),

            // Values Section
            FadeInUp(
              delay: const Duration(milliseconds: 150),
              child: _buildSection(
                title: 'हमारे मूल्य',
                content:
                    'सत्यता, निष्पक्षता और गहराई - ये तीन स्तंभ हैं जिन पर विवेचना-ओज की नींव खड़ी है। हम ऐसी पत्रकारिता में विश्वास करते हैं जो तथ्यों पर आधारित हो, सभी दृष्टिकोणों को सम्मान दे, और पाठकों को सूचित निर्णय लेने में सहायता करे।',
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 24),

            // Content Section
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _buildSection(
                title: 'हमारी सामग्री',
                content:
                    'विवेचना-ओज राजनीति, अर्थव्यवस्था, प्रौद्योगिकी, विज्ञान, स्वास्थ्य, शिक्षा और संस्कृति पर विस्तृत और विचारशील लेख प्रकाशित करती है। हमारे लेखक अनुभवी पत्रकार, विद्वान और विशेषज्ञ हैं जो महत्वपूर्ण विषयों पर प्रकाश डालते हैं।',
                isDark: isDark,
              ),
            ),
            const SizedBox(height: 24),

            // Team Section
            FadeInUp(
              delay: const Duration(milliseconds: 250),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'हमारी टीम',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimaryOn(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTeamMember('संपादक', 'नीलम त्रिपाठी', isDark, imagePath: 'assets/sampadak_photo.jpg'),
                      _buildTeamMember('सह-संपादक', 'मनोज त्रिपाठी', isDark),
                      _buildTeamMember('ग्राफ़िक डिज़ाइनर / प्रभार्य', 'ओजस्व त्रिपाठी', isDark, imagePath: 'assets/prabhaary_photo.jpg'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Contact Section
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? DesignTokens.cardColorOn(isDark) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryRed.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'संपर्क करें',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: DesignTokens.textPrimaryOn(isDark),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildContactItem(
                      icons: Icons.email_outlined,
                      label: 'ईमेल',
                      value: 'vivechanaoaj@gmail.com',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildContactItem(
                      icons: Icons.phone_outlined,
                      label: 'फोन',
                      value: '+91-7007151488',
                      isDark: isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildContactItem(
                      icons: Icons.location_on_outlined,
                      label: 'पता',
                      value: 'आनंद कुटी, नेशनल रोड मौदहा - हमीरपुर, 210507',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Social Media Section
            FadeInUp(
              delay: const Duration(milliseconds: 350),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'हमें अनुसरण करें',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimaryOn(isDark),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton('इंस्टाग्राम', Icons.photo_camera_outlined, 'https://www.instagram.com/vivechanaoj?igsh=d3U0czcwaTF6ZnVz', isDark),
                      const SizedBox(width: 16),
                      _buildSocialButton('लिंक्डइन', Icons.business, 'https://www.linkedin.com/company/vivechana-oj/', isDark),
                      const SizedBox(width: 16),
                      _buildSocialButton('वेबसाइट', Icons.language, null, isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Footer
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Center(
                child: Text(
                  '© 2026 विवेचना-ओज पत्रिका। सर्वाधिकार सुरक्षित।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: DesignTokens.textSecondaryOn(isDark),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: DesignTokens.textPrimaryOn(isDark),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: TextStyle(
            fontSize: 14,
            height: 1.6,
            color: DesignTokens.textSecondaryOn(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMember(String role, String name, bool isDark, {String? imagePath}) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: imagePath == null ? AppColors.appbarGradient : null,
            shape: BoxShape.circle,
            image: imagePath != null ? DecorationImage(
              image: AssetImage(imagePath),
              fit: BoxFit.cover,
            ) : null,
          ),
          child: imagePath == null ? const Icon(Icons.person, size: 40, color: Colors.white) : null,
        ),
        const SizedBox(height: 8),
        Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DesignTokens.textPrimaryOn(isDark),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          role,
          style: TextStyle(
            fontSize: 10,
            color: DesignTokens.textSecondaryOn(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildContactItem({
    required IconData icons,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icons, size: 18, color: AppColors.primaryRed),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: DesignTokens.textSecondaryOn(isDark),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.textPrimaryOn(isDark),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSocialButton(String label, IconData icon, String? url, bool isDark) {
    return GestureDetector(
      onTap: () async {
        if (url == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('वेबसाइट शीघ्र ही लॉन्च होगी'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          final uri = Uri.parse(url);
          try {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } catch (_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label खोलने में समस्या हुई')),
              );
            }
          }
        }
      },
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: DesignTokens.cardColorOn(isDark),
              border: Border.all(color: AppColors.primaryRed, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primaryRed, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: DesignTokens.textSecondaryOn(isDark),
            ),
          ),
        ],
      ),
    );
  }
}

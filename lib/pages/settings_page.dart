import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import 'package:animate_do/animate_do.dart';
import '../main.dart'; // For globalTextScale
import '../services/notification_service.dart';
import '../services/account_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'contact_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _textSize = 'मध्यम';
  String _appVersion = 'लोड हो रहा है...';
  String _cacheSizeStr = 'गणना की जा रही है...';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _updateCacheSize();
  }

  void _updateCacheSize() {
    final bytes = PaintingBinding.instance.imageCache.currentSizeBytes;
    if (mounted) {
      setState(() {
        if (bytes == 0) {
          _cacheSizeStr = 'अस्थायी डेटा हटाएं (0 MB)';
        } else {
          _cacheSizeStr = 'अस्थायी डेटा ${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB हटाएं';
        }
      });
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final packageInfo = await PackageInfo.fromPlatform();
    
    if (!mounted) return;
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _textSize = prefs.getString('text_size_str') ?? 'मध्यम';
      _appVersion = 'v${packageInfo.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        backgroundColor: DesignTokens.primary,
        title: const Text(
          'सेटिंग्स',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Display Section
          FadeInUp(
            child: _buildSectionHeader('डिस्प्ले', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 50),
            child: _buildSettingItem(
              context,
              icon: Icons.notifications_outlined,
              title: 'सूचनाएँ',
              subtitle: 'नई खबरों के लिए सूचनाएँ प्राप्त करें',
              onTap: () async {
                final newValue = !_notificationsEnabled;
                setState(() => _notificationsEnabled = newValue);
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('notifications_enabled', newValue);
                if (newValue) {
                  NotificationService().startPeriodicNewsCheck();
                } else {
                  NotificationService().stopPeriodicNewsCheck();
                }
              },
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) async {
                  setState(() => _notificationsEnabled = value);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('notifications_enabled', value);
                  if (value) {
                    NotificationService().startPeriodicNewsCheck();
                  } else {
                    NotificationService().stopPeriodicNewsCheck();
                  }
                },
                activeThumbColor: AppColors.primaryRed,
              ),
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // Content Section
          FadeInUp(
            delay: const Duration(milliseconds: 150),
            child: _buildSectionHeader('सामग्री', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 200),
            child: _buildSettingItem(
              context,
              icon: Icons.text_fields,
              title: 'टेक्स्ट का आकार',
              subtitle: _textSize,
              onTap: () => _showTextSizeDialog(isDark),
              isDark: isDark,
            ),
          ),

          const SizedBox(height: 24),

          // Storage Section
          FadeInUp(
            delay: const Duration(milliseconds: 300),
            child: _buildSectionHeader('स्टोरेज', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 350),
            child: _buildSettingItem(
              context,
              icon: Icons.delete_outline,
              title: 'कैश साफ़ करें',
              subtitle: _cacheSizeStr,
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryLight),
              onTap: () => _showClearCacheDialog(isDark),
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // Support Section
          FadeInUp(
            delay: const Duration(milliseconds: 400),
            child: _buildSectionHeader('सहायता / Support', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 450),
            child: _buildSettingItem(
              context,
              icon: Icons.support_agent_outlined,
              title: 'Contact Us',
              subtitle: 'Get help, support, or contact the developer',
              trailing: const Icon(Icons.chevron_right, color: AppColors.primaryLight),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ContactPage()),
                );
              },
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // About Section
          FadeInUp(
            delay: const Duration(milliseconds: 500),
            child: _buildSectionHeader('अन्य', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 550),
            child: _buildSettingItem(
              context,
              icon: Icons.language,
              title: 'भाषा',
              subtitle: 'हिंदी',
              isDark: isDark,
            ),
          ),
          FadeInUp(
            delay: const Duration(milliseconds: 600),
            child: _buildSettingItem(
              context,
              icon: Icons.info_outline,
              title: 'संस्करण',
              subtitle: _appVersion,
              isDark: isDark,
            ),
          ),
          const SizedBox(height: 24),

          // Account Section
          FadeInUp(
            delay: const Duration(milliseconds: 650),
            child: _buildSectionHeader('खाता', isDark),
          ),
          const SizedBox(height: 12),
          FadeInUp(
            delay: const Duration(milliseconds: 700),
            child: _buildDeleteAccountItem(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryRed,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: AppColors.primaryRed, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTextSizeDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.cardColorOn(isDark),
        title: Text(
          'टेक्स्ट का आकार',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['छोटा', 'मध्यम', 'बड़ा'].map((size) {
            return RadioListTile<String>(
              title: Text(
                size,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              value: size,
              groupValue: _textSize,
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _textSize = value);
                  Navigator.pop(context);
                  
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('text_size_str', value);
                  
                  double scale = 1.0;
                  if (value == 'छोटा') scale = 0.85;
                  if (value == 'बड़ा') scale = 1.25;
                  
                  await prefs.setDouble('text_scale', scale);
                  globalTextScale.value = scale;
                }
              },
              activeColor: AppColors.primaryRed,
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showClearCacheDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: DesignTokens.cardColorOn(isDark),
        title: Text(
          'कैश साफ़ करें',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'क्या आप अस्थायी डेटा हटाना चाहते हैं?',
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('रद्द करें'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);

              // Clear Flutter image cache
              PaintingBinding.instance.imageCache.clear();
              PaintingBinding.instance.imageCache.clearLiveImages();

              // Update the displayed cache size
              _updateCacheSize();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('कैश साफ़ किया गया')),
              );
            },
            child: Text(
              'साफ़ करें',
              style: TextStyle(color: AppColors.primaryRed),
            ),
          ),
        ],
      ),
    );
  }


  // ── Account Deletion ────────────────────────────────────────────────────────

  Widget _buildDeleteAccountItem(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(isDark ? 0.12 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDeleteAccountDialog(isDark),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'खाता हटाएँ (Delete Account)',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'अपना खाता और डेटा स्थायी रूप से हटाएँ',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.red),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DesignTokens.cardColorOn(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.warning_amber_rounded,
            color: Colors.red, size: 40),
        title: Text(
          'खाता हटाएँ?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'यह कार्रवाई स्थायी है और इसे पूर्ववत नहीं किया जा सकता है। आपका सभी डेटा (प्रोफ़ाइल, लेख, इतिहास) हटा दिया जाएगा।\n\nक्या आप वास्तव में अपना खाता हटाना चाहते हैं?',
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('रद्द करें'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              AccountService().deleteAccount(context);
            },
            child: const Text('हटाएँ (Delete)'),
          ),
        ],
      ),
    );
  }
}

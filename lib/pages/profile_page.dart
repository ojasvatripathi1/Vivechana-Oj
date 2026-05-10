import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';
import 'package:animate_do/animate_do.dart';
import 'saved_articles_page.dart';
import 'settings_page.dart';
import 'soochnayen_page.dart';
import 'reading_history_page.dart';
import 'about_us_page.dart';
import 'contact_us_page.dart';
import 'terms_and_conditions_page.dart';
import 'refund_policy_page.dart';
import 'writer_registration_page.dart';
import 'writer_edit_profile_page.dart';
import 'writer_tracking_page.dart';
import '../utils/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  int _savedCount = 0;
  int _readCount = 0;
  int _commentCount = 0;
  bool _statsLoaded = false;

  void _loadStats(String uid) {
    if (_statsLoaded) return;
    _statsLoaded = true;

    // Saved articles count
    FirebaseFirestore.instance
        .collection('users').doc(uid).collection('saved_articles')
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _savedCount = snap.docs.length);
    });

    // Reading history count
    FirebaseFirestore.instance
        .collection('users').doc(uid).collection('reading_history')
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _readCount = snap.docs.length);
    });

    // Comments count (across all news articles authored by this user)
    FirebaseFirestore.instance
        .collectionGroup('comments')
        .where('authorId', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (mounted) setState(() => _commentCount = snap.docs.length);
    });
  }
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryLight),
          );
        }
        final user = snapshot.data;
        if (user == null) return _buildLoggedOutView(isDark);
        return _buildLoggedInView(user, isDark);
      },
    );
  }

  Widget _buildLoggedOutView(bool isDark) {
    final bg = DesignTokens.scaffoldOn(isDark);
    return Scaffold(
      backgroundColor: bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryRed],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryRed.withOpacity(0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_outline_rounded, size: 64, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              FadeIn(
                child: Text(
                  'स्वागत है!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimaryOn(isDark),
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              FadeIn(
                delay: const Duration(milliseconds: 150),
                child: Text(
                  'विशेष लेख पढ़ने और पसंदीदा सूची सहेजने के लिए साइन इन करें।',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: DesignTokens.textSecondaryOn(isDark),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeInUp(
                child: _isLoading
                    ? CircularProgressIndicator(color: AppColors.primaryLight)
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Image.network(
                            'https://www.gstatic.com/images/branding/product/1x/googleg_24dp.png',
                            width: 20,
                            height: 20,
                          ),
                          label: const Text(
                            'गूगल से साइन इन करें',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            await _authService.signInWithGoogle();
                            if (mounted) setState(() => _isLoading = false);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoggedInView(User user, bool isDark) {
    _loadStats(user.uid);
    final bg = DesignTokens.scaffoldOn(isDark);
    final cardBg = DesignTokens.cardColorOn(isDark);

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // Profile Header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.appbarGradient,
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    children: [
                      FadeInDown(
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.accentOrange, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accentOrange.withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 48,
                            backgroundImage: NetworkImage(
                              user.photoURL ??
                                  'https://www.gravatar.com/avatar/00000000000000000000000000000000?d=mp&f=y',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Builder(
                        builder: (context) {
                          final bool isGuest = user.isAnonymous || user.email == null || user.email!.isEmpty;
                          return Column(
                            children: [
                              FadeInUp(
                                child: Text(
                                  isGuest ? 'अतिथि (Guest)' : (user.displayName ?? 'उपयोगकर्ता'),
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (!isGuest && user.email != null && user.email!.isNotEmpty)
                                FadeInUp(
                                  delay: const Duration(milliseconds: 100),
                                  child: Text(
                                    user.email!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.7),
                                      fontWeight: FontWeight.w400,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              
                              if (isGuest)
                                FadeInUp(
                                  delay: const Duration(milliseconds: 120),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: ElevatedButton.icon(
                                      icon: Image.network(
                                        'https://www.gstatic.com/images/branding/product/1x/googleg_24dp.png',
                                        width: 18,
                                        height: 18,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.g_mobiledata_rounded,
                                          size: 20,
                                          color: AppColors.primaryDark,
                                        ),
                                      ),
                                      label: const Text(
                                        'स्थायी खाता बनाएँ (Sign In)',
                                        style: TextStyle(
                                          fontSize: 14, 
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await _authService.signInWithGoogle();
                                        if (mounted) setState(() {});
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primaryDark,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        elevation: 4,
                                        shadowColor: Colors.black45,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      
                      // WRITER BADGE
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('writer_registrations')
                            .where('uid', isEqualTo: user.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                            return FadeInUp(
                              delay: const Duration(milliseconds: 150),
                              child: Container(
                                margin: const EdgeInsets.only(top: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.accentOrange.withOpacity(0.2),
                                  border: Border.all(color: AppColors.accentOrange.withOpacity(0.6)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified, color: AppColors.accentOrange, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'सत्यापित लेखक',
                                      style: TextStyle(
                                        color: AppColors.accentOrange,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      // Stats row
                      FadeInUp(
                        delay: const Duration(milliseconds: 200),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatChip('$_savedCount', 'पसंदीदा'),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            _buildStatChip('$_readCount', 'पढ़े गए'),
                            Container(
                              width: 1,
                              height: 24,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            _buildStatChip('$_commentCount', 'टिप्पणियाँ'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Menu Options
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'मेरा खाता',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textSecondaryOn(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('writer_registrations')
                        .where('uid', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      bool hasRegistration = false;
                      bool isApproved = false;
                      bool isPending = false;
                      bool isRejected = false;
                      Map<String, dynamic>? regDataMap;

                      if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                        hasRegistration = true;
                        regDataMap = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                        final status = regDataMap['status'] as String? ?? 'pending';
                        isApproved = status == 'approved';
                        isPending = status == 'pending';
                        isRejected = status == 'rejected';
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Status Banner ──────────────────────────────
                          if (isPending)
                            _buildStatusBanner(
                              icon: Icons.hourglass_top_rounded,
                              message: 'आपका लेखक आवेदन समीक्षाधीन है। अनुमोदन मिलने पर आप रचनाएँ प्रकाशित कर सकेंगे।',
                              color: Colors.orange,
                              bgColor: Colors.orange.shade50,
                            ),
                          if (isRejected)
                            _buildStatusBanner(
                              icon: Icons.cancel_outlined,
                              message: regDataMap?['rejectionReason'] != null && regDataMap!['rejectionReason'].toString().trim().isNotEmpty
                                ? 'आपका लेखक खाता निलंबित/अस्वीकृत कर दिया गया है।\nनिलंबन का कारण: ${regDataMap['rejectionReason']}'
                                : 'आपका लेखक आवेदन अस्वीकृत हो गया। आप पुनः आवेदन कर सकते हैं।',
                              color: Colors.red,
                              bgColor: Colors.red.shade50,
                            ),
                          if (isPending || isRejected || isApproved)
                            const SizedBox(height: 12),

                          // ── Menu Section ───────────────────────────────
                          _buildMenuSection(
                            cardBg: cardBg,
                            isDark: isDark,
                            items: [
                              if (isApproved)
                                const _MenuItem(Icons.edit_document, 'प्रोफ़ाइल संपादित करें', AppColors.accentOrange)
                              else if (isRejected)
                                const _MenuItem(Icons.edit_document, 'लेखक पंजीकरण', AppColors.accentOrange)
                              else if (!hasRegistration)
                                const _MenuItem(Icons.edit_document, 'लेखक पंजीकरण', AppColors.accentOrange),
                              // If pending — no registration item (application is being reviewed)
                              if (hasRegistration)
                                const _MenuItem(Icons.track_changes_rounded, 'मेरी स्थिति', AppColors.primaryRed),
                              const _MenuItem(Icons.bookmark_outline_rounded, 'पसंदीदा लेख', AppColors.accentOrange),
                              const _MenuItem(Icons.history_rounded, 'पढ़ने का इतिहास', AppColors.primaryLight),
                              const _MenuItem(Icons.notifications_outlined, 'सूचनाएँ', AppColors.primaryRed),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'सेटिंग्स',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textSecondaryOn(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMenuSection(
                    cardBg: cardBg,
                    isDark: isDark,
                    items: [
                      _MenuItem(Icons.settings_outlined, 'सेटिंग्स', Colors.blueGrey),
                      _MenuItem(Icons.help_outline_rounded, 'संपर्क करें', Colors.teal),
                      _MenuItem(Icons.info_outline_rounded, 'हमारे बारे में', Colors.indigo),
                      _MenuItem(Icons.description_outlined, 'नियम और शर्तें', AppColors.primaryLight),
                      _MenuItem(Icons.account_balance_wallet_outlined, 'धनवापसी नीति', AppColors.accentOrange),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // ── My Articles Section ──────────────────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('writer_articles')
                        .where('authorId', isEqualTo: user.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return const SizedBox.shrink();
                      // Sort locally by createdAt descending
                      final sorted = [...docs];
                      sorted.sort((a, b) {
                        final aTs = (a.data() as Map)['createdAt'];
                        final bTs = (b.data() as Map)['createdAt'];
                        if (aTs == null || bTs == null) return 0;
                        return (bTs as dynamic).compareTo(aTs);
                      });
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'मेरी रचनाएँ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: DesignTokens.textSecondaryOn(isDark),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: sorted.asMap().entries.map((entry) {
                                final i = entry.key;
                                final doc = entry.value;
                                final data = doc.data() as Map<String, dynamic>;
                                final title = data['title'] as String? ?? '';
                                final category = data['category'] as String? ?? '';
                                final status = data['status'] as String? ?? 'pending';

                                Color statusColor;
                                IconData statusIcon;
                                String statusLabel;
                                switch (status) {
                                  case 'approved':
                                    statusColor = Colors.green;
                                    statusIcon = Icons.check_circle_outline;
                                    statusLabel = 'प्रकाशित';
                                    break;
                                  case 'rejected':
                                    statusColor = Colors.red;
                                    statusIcon = Icons.cancel_outlined;
                                    statusLabel = 'अस्वीकृत';
                                    break;
                                  default: // pending
                                    statusColor = Colors.orange;
                                    statusIcon = Icons.hourglass_top_rounded;
                                    statusLabel = 'समीक्षाधीन';
                                }

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryRed.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.article_outlined, size: 18, color: AppColors.primaryRed),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: DesignTokens.textPrimaryOn(isDark),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  category,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: DesignTokens.textSecondaryOn(isDark),
                                                  ),
                                                ),
                                                if (status == 'rejected' && data['rejectionReason'] != null && data['rejectionReason'].toString().trim().isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'कारण: ${data['rejectionReason']}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontStyle: FontStyle.italic,
                                                      color: Colors.red.shade700,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(statusIcon, size: 12, color: statusColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (i < sorted.length - 1)
                                      Divider(
                                        height: 1,
                                        indent: 64,
                                        color: DesignTokens.dividerOn(isDark),
                                      ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                      );
                    },
                  ),

                  // Sign out
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('लॉग आउट करें'),
                      onPressed: () => _authService.signOut(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryRed,
                        side: BorderSide(color: AppColors.primaryRed.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner({
    required IconData icon,
    required String message,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: color.withOpacity(0.85),
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection({
    required Color cardBg,
    required bool isDark,
    required List<_MenuItem> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          return Column(
            children: [
              InkWell(
                onTap: () async {
                  switch (item.title) {
                    case 'लेखक पंजीकरण':
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null || user.isAnonymous) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('लेखक पंजीकरण के लिए कृपया पहले लॉगिन करें।')),
                        );
                        // Force log out so they hit the Google Sign In screen
                        await AuthService().signOut(); 
                        return;
                      }
                      
                      Navigator.push(
                        context,
                        AppRoutes.slideUp(const WriterRegistrationPage()),
                      );
                      break;
                    case 'प्रोफ़ाइल संपादित करें':
                      final edited = await Navigator.push(
                        context,
                        AppRoutes.slideUp(const WriterEditProfilePage()),
                      );
                      if (edited == true && mounted) {
                        // Force reload FirebaseAuth user so StreamBuilder shows fresh data
                        await FirebaseAuth.instance.currentUser?.reload();
                        setState(() {});
                      }
                      break;
                    case 'पसंदीदा लेख':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SavedArticlesPage(),
                        ),
                      );
                      break;
                    case 'पढ़ने का इतिहास':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReadingHistoryPage(),
                        ),
                      );
                      break;
                    case 'मेरी स्थिति':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WriterTrackingPage(),
                        ),
                      );
                      break;
                    case 'सूचनाएँ':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SoochnaenPage(),
                        ),
                      );
                      break;
                    case 'सेटिंग्स':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                      break;
                    case 'संपर्क करें':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactUsPage(),
                        ),
                      );
                      break;
                    case 'हमारे बारे में':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AboutUsPage(),
                        ),
                      );
                      break;
                    case 'नियम और शर्तें':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsAndConditionsPage(),
                        ),
                      );
                      break;
                    case 'धनवापसी नीति':
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RefundPolicyPage(),
                        ),
                      );
                      break;
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: item.color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(item.icon, size: 18, color: item.color),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.textPrimaryOn(isDark),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: DesignTokens.textSecondaryOn(isDark),
                      ),
                    ],
                  ),
                ),
              ),
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 66,
                  color: DesignTokens.dividerOn(isDark),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final Color color;
  const _MenuItem(this.icon, this.title, this.color);
}

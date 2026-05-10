import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../models/magazine_edition.dart';
import '../services/magazine_service.dart';
import 'magazine_reader_page.dart';
import 'admin_edit_magazine_page.dart';

class MagazinePage extends StatefulWidget {
  const MagazinePage({super.key});

  @override
  State<MagazinePage> createState() => _MagazinePageState();
}

class _MagazinePageState extends State<MagazinePage> {
  final MagazineService _service = MagazineService();
  StreamSubscription<List<MagazineEdition>>? _magazineSub;
  List<MagazineEdition> _editions = [];
  bool _isAdmin = false;
  bool _loadingEditions = true;
  bool _editionsError = false;

  @override
  void initState() {
    super.initState();
    _loadEditions();
    _loadAdminStatus();
  }

  void _loadEditions() {
    if (mounted) {
      setState(() {
        _loadingEditions = true;
        _editionsError = false;
      });
    }
    _magazineSub?.cancel();
    _magazineSub = _service.getMagazinesStream().listen(
      (magazines) {
        if (mounted) {
          setState(() {
            _editions = magazines;
            _loadingEditions = false;
          });
        }
      },
      onError: (error) {
        debugPrint('Magazine stream error: $error');
        if (error is FirebaseException && error.code == 'permission-denied') {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.isAnonymous) {
            FirebaseAuth.instance.signOut();
          }
        }
        if (mounted) {
          setState(() {
            _loadingEditions = false;
            _editionsError = true;
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _magazineSub?.cancel();
    super.dispose();
  }

  Future<void> _loadAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final status = await _service.getMembershipStatus(user.uid);
      if (mounted) setState(() => _isAdmin = status['isAdmin'] == true);
    }
  }

  /// Called by RefreshIndicator on pull-to-refresh.
  Future<void> _refreshAll() async {
    await Future.wait([
      Future(() => _loadEditions()),
      _loadAdminStatus(),
    ]);
  }

  void _onTapEdition(MagazineEdition edition) {
    // Check if the magazine PDF is actually uploaded
    if (!edition.isUploaded) {
      showDialog(
        context: context,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: DesignTokens.cardColorOn(isDark),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            icon: const Icon(Icons.hourglass_top_rounded, color: AppColors.accentOrange, size: 48),
            title: Text(
              'जल्द आ रहा है!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: DesignTokens.textPrimaryOn(isDark),
              ),
            ),
            content: Text(
              '${edition.title} का अंक अभी अपलोड नहीं किया गया है। कृपया कुछ समय बाद पुनः प्रयास करें।',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: DesignTokens.textSecondaryOn(isDark),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ठीक है', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
      return;
    }

    // All editions are free — open reader directly
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MagazineReaderPage(edition: edition)),
    );
  }

  void _onEditEdition(MagazineEdition edition) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditMagazinePage(edition: edition),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isAdmin = _isAdmin;

    // ── Loading state ─────────────────────────────────────────────
    if (_loadingEditions) {
      return Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        body: RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: _refreshAll,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(isDark),
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primaryRed),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Error state ───────────────────────────────────────────────
    if (_editionsError) {
      return Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        body: RefreshIndicator(
          color: AppColors.primaryRed,
          onRefresh: _refreshAll,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(isDark),
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('मैगज़ीन लोड नहीं हो सकी।', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('कृपया इंटरनेट कनेक्शन जांचें।', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _loadEditions,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('पुनः प्रयास करें'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── BUG FIX: Always pick the most recently uploaded edition as hero ──
    // Previously the logic matched only the current calendar month's ID (e.g.
    // '2026-03'), so if that month wasn't uploaded it fell back to a placeholder,
    // hiding any uploaded editions (like January 2026) in the "past editions" grid.
    // Now we simply take the first element from the already-sorted (descending) list.
    MagazineEdition heroEdition;
    List<MagazineEdition> pastEditions;

    if (_editions.isNotEmpty) {
      // Editions are already sorted descending by ID — first = most recent
      heroEdition = _editions.first;
      
      // ── DEDUPLICATION: Hide the hero month from the grid below ──
      // Some combined issues (e.g. "मार्च-फ़रवरी") may overlap with the single month hero.
      // We filter out any past edition that shares the same year and contains the hero's month.
      final String heroMonth = heroEdition.month;
      final int heroYear = heroEdition.year;
      
      pastEditions = _editions.skip(1).where((e) {
        if (e.year != heroYear) return true;
        // If the past edition month contains the hero month (e.g. "मार्च" in "मार्च-फ़रवरी")
        // or if it's an exact match, skip it to avoid duplication.
        if (e.month.contains(heroMonth) || heroMonth.contains(e.month)) {
          return false;
        }
        return true;
      }).toList();
    } else {
      // Truly empty database fallback
      final now = DateTime.now();
      final monthStr = now.month.toString().padLeft(2, '0');
      final currentMonthId = '${now.year}-$monthStr';
      final List<String> hindiMonths = [
        'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
        'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
      ];
      final String currentMonthName = hindiMonths[now.month - 1];
      heroEdition = MagazineEdition(
        id: currentMonthId,
        title: '$currentMonthName ${now.year}',
        subtitle: 'जल्द आ रहा है...',
        coverUrl: '',
        pdfUrl: '',
        month: currentMonthName,
        year: now.year,
        isLatest: true,
        isUploaded: false,
        pageCount: 0,
        highlights: ['नया अंक जल्द ही प्रकाशित किया जाएगा।'],
      );
      pastEditions = [];
    }

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      body: RefreshIndicator(
        color: AppColors.primaryRed,
        onRefresh: _refreshAll,
        child: CustomScrollView(
          slivers: [
            // ── AppBar (matches home/news style) ─────────────────────
            _buildAppBar(isDark),

            // ── Latest edition hero ───────────────────────────────────
            SliverToBoxAdapter(
              child: _buildLatestHero(isDark, heroEdition, isAdmin),
            ),

            // ── Section header ────────────────────────────────────────
            if (pastEditions.isNotEmpty)
              SliverToBoxAdapter(
                child: _buildSectionHeader('पिछले अंक', isDark),
              ),

            // ── Past editions grid ────────────────────────────────────
            if (pastEditions.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.62,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return FadeInUp(
                        delay: Duration(milliseconds: index * 80),
                        child: _buildEditionCard(pastEditions[index], isDark, isAdmin),
                      );
                    },
                    childCount: pastEditions.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      snap: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 68,
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      titleSpacing: 16,
      title: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentOrange, width: 2),
            ),
            child: ClipOval(
              child: Image.asset('assets/vivechana-oj-logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'मैगज़ीन',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  color: DesignTokens.textPrimaryOn(isDark),
                  letterSpacing: 0.3,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.menu_book_rounded, size: 12, color: AppColors.accentOrange),
                  const SizedBox(width: 3),
                  Text(
                    'विवेचना-ओज',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentOrange,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;
              return GestureDetector(
                onTap: () {},
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primaryLight.withOpacity(0.15),
                  backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
                  child: user?.photoURL == null
                      ? Icon(Icons.person_outline, color: AppColors.primaryLight, size: 20)
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMemberBanner(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.magazineGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'आप वार्षिक सदस्य हैं • सभी अंक पढ़ें',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLatestHero(bool isDark, MagazineEdition latest, bool isAdmin) {
    return GestureDetector(
      onTap: () => _onTapEdition(latest),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        height: 260,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withOpacity(0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Cover image
              Image.network(
                latest.coverUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryDark,
                  child: const Icon(Icons.book_rounded, color: Colors.white54, size: 60),
                ),
              ),

              // Gradient overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xDD1A0000)],
                    stops: [0.3, 1.0],
                  ),
                ),
              ),

              // Latest badge
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.new_releases_rounded, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text('नवीनतम अंक', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),

              // Admin Edit Button
              if (isAdmin && latest.isUploaded)
                Positioned(
                  top: 14,
                  right: 64, // Shift left of delete button
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _onEditEdition(latest),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),

              // Admin Delete Button
              if (isAdmin && latest.isUploaded)
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _confirmDelete(latest),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),

              // Content bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latest.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        latest.subtitle,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Highlights
                          Expanded(
                            child: Text(
                              latest.highlights.take(2).join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Read button — always free
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.menu_book_rounded,
                                  size: 13,
                                  color: AppColors.primaryDark,
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'पढ़ें',
                                  style: TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.accentOrange],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: DesignTokens.textPrimaryOn(isDark),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(MagazineEdition edition) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: DesignTokens.cardColorOn(isDark),
          title: Text(
            'मैगज़ीन हटाएं (Delete Magazine)',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: DesignTokens.textPrimaryOn(isDark),
            ),
          ),
          content: Text(
            'क्या आप वाकई "${edition.title}" मैगज़ीन को स्थायी रूप से हटाना चाहते हैं? यह कवर फोटो और पीडीएफ दोनों हटा देगा।\n(Are you sure you want to permanently delete this magazine? This removes both the cover photo and PDF.)',
            style: TextStyle(
              fontSize: 14,
              color: DesignTokens.textSecondaryOn(isDark),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'रद्द करें (Cancel)',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('हटाएं (Delete)'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('मैगज़ीन हटाई जा रही है...')),
    );

    final success = await _service.deleteMagazine(edition);

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('मैगज़ीन सफलतापूर्वक हटा दी गई!'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('मैगज़ीन हटाने में त्रुटि।'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildEditionCard(MagazineEdition edition, bool isDark, bool isAdmin) {
    return GestureDetector(
      onTap: () => _onTapEdition(edition),
      child: Container(
        decoration: BoxDecoration(
          color: DesignTokens.cardColorOn(isDark),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.25 : 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      edition.coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.primaryDark.withOpacity(0.8),
                        child: const Icon(Icons.book_outlined, color: Colors.white38),
                      ),
                    ),
                    // Read indicator — always free
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.shade700,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.menu_book_rounded,
                              size: 10,
                              color: Colors.white,
                            ),
                            SizedBox(width: 3),
                            Text(
                              'पढ़ें',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                      // Coming soon overlay for unuploaded editions
                      if (!edition.isUploaded)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                          ),
                          child: const Center(
                            child: Text(
                              'जल्द आ रहा है',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
              // Admin Edit Button
              if (isAdmin && edition.isUploaded)
                Positioned(
                  top: 8,
                  right: 44, // To the left of delete button
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _onEditEdition(edition),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),

              // Admin Delete Button
              if (isAdmin && edition.isUploaded)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(30),
                      onTap: () => _confirmDelete(edition),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ),
                    ],
                  ),
                ),
              ),

            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      edition.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: DesignTokens.textPrimaryOn(isDark),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      edition.subtitle,
                      style: TextStyle(
                        fontSize: 10,
                        color: DesignTokens.textSecondaryOn(isDark),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        Icon(Icons.menu_book_outlined, size: 11, color: DesignTokens.textSecondaryOn(isDark)),
                        const SizedBox(width: 3),
                        Text(
                          '${edition.pageCount} पृष्ठ',
                          style: TextStyle(fontSize: 10, color: DesignTokens.textSecondaryOn(isDark)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

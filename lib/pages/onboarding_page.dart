import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import '../main.dart'; // to navigate to AuthWrapper
import '../widgets/fade_in_animation.dart';
import 'login_page.dart'; // to navigate to LoginPage
import 'home_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final AuthService _authService = AuthService();

  int _currentPage = 0;
  bool _isLoading = false;
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      if (_pageController.hasClients) {
        setState(() {
          _scrollOffset = _pageController.page ?? 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _completeOnboardingAndGo(Widget targetPage) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_time', false);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        _completeOnboardingAndGo(const HomePage());
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInAsGuest();
      if (userCredential != null && mounted) {
        _completeOnboardingAndGo(const HomePage());
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131313),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              _buildParallaxWrapper(0, _buildNewScreenOne()),
              _buildParallaxWrapper(1, _buildNewScreenTwo()),
              _buildParallaxWrapper(2, _buildNewScreenThree()),
            ],
          ),
          
          if (_isLoading)
            Container(
              color: AppColors.primaryDark.withOpacity(0.85),
              child: const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentOrange,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildParallaxWrapper(int index, Widget child) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double pageValue = 0.0;
        if (_pageController.hasClients && _pageController.position.haveDimensions) {
          pageValue = (_pageController.page ?? 0.0) - index;
        } else {
          pageValue = _currentPage.toDouble() - index;
        }
        
        // Horizontal shift for parallax
        double horizontalShift = pageValue * 150;
        
        return Opacity(
          opacity: (1 - pageValue.abs()).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(horizontalShift, 0),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildOldScreenWrapper({required Widget child, required bool showNext}) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryDark,
                Color(0xFF3A0A0A),
                AppColors.primaryLight,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.accentOrange, AppColors.primaryRed],
              ),
            ),
          ),
        ),

        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AnimatedOpacity(
                      opacity: _currentPage == 2 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: TextButton(
                        onPressed: () => _pageController.animateToPage(
                          2,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                        ),
                        child: Text(
                          'छोड़ें (Skip)',
                          style: GoogleFonts.notoSansDevanagari(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: child,
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(32, 20, 32, 48),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        3,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8,
                          width: _currentPage == index ? 24 : 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.accentOrange
                                : Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: _currentPage == index
                                ? [
                                    BoxShadow(
                                      color: AppColors.accentOrange.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: showNext
                          ? SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                key: const ValueKey('next_btn'),
                                onPressed: _nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primaryDark,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'आगे बढ़ें',
                                  style: GoogleFonts.notoSansDevanagari(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 1: NEW INTRO / HOOK
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNewScreenOne() {
    return Container(
      color: const Color(0xFF131313),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(_scrollOffset * 40 - (0 * 40), 0),
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCC4Xhzt5bXzl-rpE26Vf9q0_RgdGi8hk_68byzn1I-ICLzz0aKkUzqlXBo4kV3wvdtA1sKJ30XSBmd9m2zC8oiuikUVNaadXFdOQLQJEe_dn7GLlGnqIbgDvF67Udw0h6DK1dZ2MhMcIoFfzpviIYbMec86FlHGwO_buu4cHmX3fnt6B-FIgBtVCmu5ARNmttknYXuEwO9BWMOupyKis4Cs5q8fujqZdMMnxmCbK198sU7-npcoc8cHhL36xOOHhhpoM_rlvZX7M0',
                        fit: BoxFit.cover,
                        alignment: Alignment(_scrollOffset - 0, 0),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF131313),
                              const Color(0xFF131313).withOpacity(0.5),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 48,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE10026),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE10026).withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'सत्यमेव जयते',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFFFF2F1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFF131313),
                padding: const EdgeInsets.only(left: 32, right: 32, top: 8, bottom: 48),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 200),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'समाचार और\n',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE5E2E1),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: 'साहित्य का संगम',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE10026),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          'स्थानीय खबरें, पत्रिकाएं और उत्कृष्ट साहित्य - अब सब कुछ आपकी अपनी भाषा में।',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE5E2E1).withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE10026),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'कदम 01 / 03',
                            style: GoogleFonts.mukta(
                              color: const Color(0xFFE5E2E1).withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 600),
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE10026),
                                foregroundColor: const Color(0xFFFFF2F1),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFFE10026).withOpacity(0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'आगे बढ़ें',
                                    style: GoogleFonts.mukta(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward, size: 24),
                                ],
                              ),
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
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF131313).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE10026).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage('assets/vivechana-oj-logo.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'विवेचना ओज',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE10026),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _pageController.animateToPage(
                        2,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Text(
                        'छोड़ें',
                        style: GoogleFonts.mukta(
                          color: const Color(0xFFE5E2E1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          IgnorePointer(
            child: Opacity(
              opacity: 0.03,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/carbon-fibre.png',
                repeat: ImageRepeat.repeat,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 2: VALUE / BENEFIT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScreenTwo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Expanded(
            flex: 6,
            child: Center(
              child: _buildUIPreviewCard(),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Text(
                  'प्रीमियम मैगज़ीन\nअब आपकी जेब में',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'हर महीने पाएं ताज़ा अंक और स्पेशल एडिशंस।\nकभी भी, कहीं भी पढ़ें और हमेशा अपडेट रहें!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUIPreviewCard() {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A0A0A), // Dark card background
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mock Image Area
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF4A1A1A), Color(0xFF5A1A1A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white70, size: 40),
            ),
          ),
          const SizedBox(height: 20),
          // Mock Text Lines
          Container(height: 12, width: 140, decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 12),
          Container(height: 12, width: 180, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 8),
          Container(height: 12, width: 100, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(6))),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 3: ACTION / CONVERSION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildScreenThree() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.accentOrange, AppColors.primaryRed],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentOrange.withOpacity(0.3),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryDark,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              children: [
                Text(
                  'क्या आप तैयार हैं\nइस सफर के लिए?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'हज़ारों पाठकों के हमारे खास समुदाय का हिस्सा बनें।\nमुफ़्त में साइन अप करें और शुरुआत करें!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 15,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16), // Reduced to prevent RenderFlex overflow

                // Primary CTA (Google)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleGoogleSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primaryDark,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.network(
                          'https://www.gstatic.com/images/branding/product/1x/googleg_24dp.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 24,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Google से तुरंत जुड़ें',
                          style: GoogleFonts.notoSansDevanagari(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Secondary CTA (Guest)
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _handleGuestSignIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'बिना लॉगिन किए एक्सप्लोर करें',
                      style: GoogleFonts.notoSansDevanagari(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),
                
                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'क्या पहले से खाता है? ',
                      style: GoogleFonts.notoSansDevanagari(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _completeOnboardingAndGo(const LoginPage());
                      },
                      child: Text(
                        'लॉग इन करें',
                        style: GoogleFonts.notoSansDevanagari(
                          color: AppColors.accentOrange,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16), // Reduced bottom margin slightly
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 3: NEW ACTION / CONVERSION
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNewScreenThree() {
    return Container(
      color: const Color(0xFF131313),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(_scrollOffset * 40 - (2 * 40), 0),
                      child: Image.asset(
                        'assets/magazine-mockup.png',
                        fit: BoxFit.cover,
                        alignment: Alignment(_scrollOffset - 2, 0),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF131313),
                              const Color(0xFF131313).withOpacity(0.5),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.4, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 48,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE10026),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE10026).withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'समुदाय से जुड़ें',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFFFF2F1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFF131313),
                padding: const EdgeInsets.only(left: 32, right: 32, top: 8, bottom: 48),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 200),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'अभी जुड़ें और\n',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE5E2E1),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: 'पढ़ना शुरू करें',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE10026),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          'हज़ारों पाठकों के समुदाय का हिस्सा बनें और अपनी पसंदीदा कहानियाँ और समाचार सहेजें।',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE5E2E1).withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE10026),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'कदम 03 / 03',
                            style: GoogleFonts.mukta(
                              color: const Color(0xFFE5E2E1).withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 600),
                            child: ElevatedButton(
                              onPressed: () {
                                _completeOnboardingAndGo(const LoginPage());
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE10026),
                                foregroundColor: const Color(0xFFFFF2F1),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFFE10026).withOpacity(0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'शुरू करें',
                                    style: GoogleFonts.mukta(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward, size: 24),
                                ],
                              ),
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
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF131313).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE10026).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage('assets/vivechana-oj-logo.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'विवेचना ओज',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE10026),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _pageController.animateToPage(
                        2,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Text(
                        'छोड़ें',
                        style: GoogleFonts.mukta(
                          color: const Color(0xFFE5E2E1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          IgnorePointer(
            child: Opacity(
              opacity: 0.03,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/carbon-fibre.png',
                repeat: ImageRepeat.repeat,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCREEN 2: NEW VALUE / BENEFIT
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNewScreenTwo() {
    return Container(
      color: const Color(0xFF131313),
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Transform.translate(
                      offset: Offset(_scrollOffset * 40 - (1 * 40), 0),
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuD438TJ034Nt1FX5iokThF41g_REhgmf4NPcE071MwDK-fyG5KgHqyMuD5NFE6P3ICCtKO6CNyr-tSXOB_fVt4oRDhdDQ8uWyEjdLf-FyLR5e2I-jzekYGyjCNvLWenncmXL9OhXB9mj9yRxOd4gYsbR_LgOPFbBnM1sG5laO_oOVLZjgIGVhsrMK35v3-T1lnAm5_DMuJf4iEVptseCk5OWsRj1tp03UxtHyAuhONs8xG9IRk4QxewEorQoq0AlUtOs6RXGNKgzJY',
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.4),
                        colorBlendMode: BlendMode.darken,
                        alignment: Alignment(_scrollOffset - 1, 0),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              const Color(0xFF131313),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 48,
                      left: 24,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE10026),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE10026).withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'डिजिटल • मैगज़ीन',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFFFF2F1),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: const Color(0xFF131313),
                padding: const EdgeInsets.only(left: 32, right: 32, top: 8, bottom: 48),
                child: SafeArea(
                  top: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 200),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'ई-मैगजीन और\n',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE5E2E1),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                              TextSpan(
                                text: 'विशेष लेख',
                                style: GoogleFonts.mukta(
                                  color: const Color(0xFFE10026),
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FadeInAnimation(
                        delay: const Duration(milliseconds: 400),
                        child: Text(
                          'बेहतरीन लेखकों के विचार और हमारी खास मासिक पत्रिका, अब डिजिटल अवतार में।',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE5E2E1).withOpacity(0.7),
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE10026),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 6,
                            width: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xFF353534),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'कदम 02 / 03',
                            style: GoogleFonts.mukta(
                              color: const Color(0xFFE5E2E1).withOpacity(0.4),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          FadeInAnimation(
                            delay: const Duration(milliseconds: 600),
                            child: ElevatedButton(
                              onPressed: _nextPage,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE10026),
                                foregroundColor: const Color(0xFFFFF2F1),
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                elevation: 8,
                                shadowColor: const Color(0xFFE10026).withOpacity(0.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'आगे बढ़ें',
                                    style: GoogleFonts.mukta(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.arrow_forward, size: 24),
                                ],
                              ),
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
          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF131313).withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE10026).withOpacity(0.2)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                              ),
                            ],
                            image: const DecorationImage(
                              image: AssetImage('assets/vivechana-oj-logo.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'विवेचना ओज',
                          style: GoogleFonts.mukta(
                            color: const Color(0xFFE10026),
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => _pageController.animateToPage(
                        2,
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                      ),
                      child: Text(
                        'छोड़ें',
                        style: GoogleFonts.mukta(
                          color: const Color(0xFFE5E2E1),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          IgnorePointer(
            child: Opacity(
              opacity: 0.03,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/carbon-fibre.png',
                repeat: ImageRepeat.repeat,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

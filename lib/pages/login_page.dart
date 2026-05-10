import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  late AnimationController _logoAnimationController;
  late AnimationController _contentAnimationController;
  late Animation<double> _logoScale;
  late Animation<double> _contentOpacity;
  late Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );

    _logoScale = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.elasticOut,
    );
    _contentOpacity = CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeIn,
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentAnimationController,
      curve: Curves.easeOut,
    ));

    _logoAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _contentAnimationController.forward();
    });
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  // ── Smooth fade+scale navigation, no jarring slide ─────────────────
  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomePage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Pure fade — no slide, so nothing "gets stuck"
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
      (Route<dynamic> route) => false,
    );
  }

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInWithGoogle();
      if (userCredential != null && mounted) {
        _navigateToHome();
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('साइन इन रद्द किया गया'),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('साइन इन विफल: ${e.toString()}'),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _handleGuestSignIn() async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await _authService.signInAsGuest();
      if (userCredential != null && mounted) {
        _navigateToHome();
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('अतिथि मोड विफल: ${e.toString()}'),
            backgroundColor: AppColors.primaryRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──────────────────────────────────
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

          // ── Top accent bar ───────────────────────────────────────
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

          // ── Main content ─────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // Logo section
                Expanded(
                  flex: 5,
                  child: Center(
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo with glowing ring
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [AppColors.accentOrange, AppColors.primaryRed],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accentOrange.withOpacity(0.4),
                                  blurRadius: 32,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryDark,
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/vivechana-oj-logo.png',
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Hindi name
                          Text(
                            'विवेचना-ओज',
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'VIVECHANA OJ',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentOrange,
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Welcome + buttons section
                Expanded(
                  flex: 4,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'आपका स्वागत है',
                              style: GoogleFonts.notoSansDevanagari(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '"विचारों की स्वतंत्र आवाज़"',
                              style: GoogleFonts.notoSansDevanagari(
                                fontSize: 14,
                                color: Colors.white60,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 36),

                            // Google Sign-In Button
                            _buildGoogleButton(),
                            const SizedBox(height: 14),

                            // Guest Button
                            _buildGuestButton(),
                            const SizedBox(height: 24),

                            // Terms note
                            Center(
                              child: Text(
                                'साइन इन करके आप हमारी सेवा शर्तें स्वीकार करते हैं',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.35),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // ── Full-screen loading overlay ──────────────────────────
          // Covers the whole screen while auth is in progress,
          // so the background can never be seen sliding/stuck.
          if (_isLoading)
            Container(
              color: AppColors.primaryDark.withOpacity(0.85),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppColors.accentOrange,
                      strokeWidth: 2.5,
                    ),
                    SizedBox(height: 20),
                    Text(
                      'साइन इन हो रहा है...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleGoogleSignIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.primaryDark,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.all(
            AppColors.primaryLight.withOpacity(0.08),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // BUG-005 FIX: Fallback icon if network unavailable
            Image.network(
              'https://www.gstatic.com/images/branding/product/1x/googleg_24dp.png',
              width: 22,
              height: 22,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.g_mobiledata_rounded,
                size: 24,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'गूगल से साइन इन करें',
              style: GoogleFonts.notoSansDevanagari(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _handleGuestSignIn,
        icon: const Icon(Icons.person_outline_rounded, size: 20),
        label: Text(
          'अतिथि के रूप में प्रवेश करें',
          style: GoogleFonts.notoSansDevanagari(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.white.withOpacity(0.4), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
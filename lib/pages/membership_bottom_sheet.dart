import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../models/magazine_edition.dart';
import '../services/magazine_service.dart';
import '../services/payment_email_service.dart';
import 'magazine_reader_page.dart';
import 'delivery_address_page.dart';

// BUG-016 FIX: Key injected via --dart-define=RAZORPAY_KEY=rzp_live_... at build time.
// For local dev the test key is the fallback. NEVER commit the live key to source control.
const String _razorpayKeyId = String.fromEnvironment(
  'RAZORPAY_KEY',
  defaultValue: 'rzp_test_SOFNM1MXVMvXzQ',
);
// ────────────────────────────────────────────────────────────────────────────

class MembershipBottomSheet extends StatefulWidget {
  final MagazineEdition edition;
  final VoidCallback onPurchaseComplete;

  const MembershipBottomSheet({
    super.key,
    required this.edition,
    required this.onPurchaseComplete,
  });

  @override
  State<MembershipBottomSheet> createState() => _MembershipBottomSheetState();
}

class _MembershipBottomSheetState extends State<MembershipBottomSheet> {
  bool _isProcessing = false;
  late Razorpay _razorpay;
  final MagazineService _service = MagazineService();

  // Which plan was last initiated so we know what to do in the callback
  String _activePlan = ''; // 'single' or 'annual'

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  // ── Razorpay Option Builders ─────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildOptions({
    required int amountPaise,
    required String description,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final contact = await PaymentEmailService.getUserContact();

    // Razorpay only accepts ASCII/Latin names — strip Devanagari/Hindi script
    final rawName = user?.displayName ?? contact['name'] ?? '';
    final safeName = _safeRazorpayName(rawName, user?.email ?? '');

    return {
      'key': _razorpayKeyId,
      'amount': amountPaise,          // in paise
      'name': 'Vivechana-Oj Patrika', // merchant name — must be ASCII
      'description': description,
      'prefill': {
        'contact': contact['phone'] ?? '',
        'email': user?.email ?? contact['email'] ?? '',
        'name': safeName,
      },
      'theme': {'color': '#9B0B1E'},
      'send_sms_hash': true,
      'retry': {'enabled': true, 'max_count': 2},
    };
  }

  /// Returns an ASCII-safe name for Razorpay prefill.
  /// Falls back to the email prefix if the name has non-Latin characters.
  String _safeRazorpayName(String name, String email) {
    // Check if name has only ASCII characters
    final asciiOnly = RegExp(r'^[\x00-\x7F]+$');
    if (name.isNotEmpty && asciiOnly.hasMatch(name.trim())) {
      return name.trim();
    }
    // Fallback: use email prefix (before @)
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return 'Customer';
  }

  // ── Payment Handlers ─────────────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final paymentId = response.paymentId ?? '';
    final orderId   = response.orderId ?? '';
    final contact   = await PaymentEmailService.getUserContact();

    if (_activePlan == 'single') {
      try {
        // ── Single Issue ─────────────────────
        await _service.saveSingleEditionPurchase(
          user.uid,
          widget.edition.id,
          paymentId: paymentId,
          orderId: orderId,
        );
        await _service.savePaymentReceipt(
          uid: user.uid,
          userEmail: user.email ?? '',
          userName: user.displayName ?? contact['name'] ?? '',
          paymentId: paymentId,
          plan: 'single',
          amountPaise: 2000,
          editionId: widget.edition.id,
          editionTitle: widget.edition.title,
        );
        
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);

        final emailToSend = user.email ?? '';
        if (emailToSend.isNotEmpty) {
          final now = DateTime.now();
          await PaymentEmailService.sendReceipt(
            toEmail: emailToSend,
            toName: user.displayName ?? contact['name'] ?? '',
            plan: 'single',
            amountPaise: 2000,
            paymentId: paymentId,
            validFrom: now,
            validUntil: now.add(const Duration(days: 30)),
            editionTitle: widget.edition.title,
          );
        }
        if (!mounted) return;
        setState(() => _isProcessing = false);
        final edition = widget.edition;
        widget.onPurchaseComplete();
        nav.pop();
        nav.push(
          MaterialPageRoute(
            builder: (_) => MagazineReaderPage(edition: edition),
          ),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text('✅ भुगतान सफल! Payment ID: $paymentId'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('पेमेंट सफल रहा, लेकिन डेटा सेव करने में त्रुटि: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } else if (_activePlan == 'annual') {
      // ── Annual Subscription ──────────────
      await _service.saveAnnualMembership(
        user.uid,
        paymentId: paymentId,
        orderId: orderId,
      );
      await _service.savePaymentReceipt(
        uid: user.uid,
        userEmail: user.email ?? '',
        userName: user.displayName ?? contact['name'] ?? '',
        paymentId: paymentId,
        plan: 'annual',
        amountPaise: 30000,
      );
      // BUG-012 FIX: Capture messenger before pop
      final messenger = ScaffoldMessenger.of(context);

      // BUG-011 FIX: Guard empty email
      final emailToSend = user.email ?? '';
      if (emailToSend.isNotEmpty) {
        final now2 = DateTime.now();
        await PaymentEmailService.sendReceipt(
          toEmail: emailToSend,
          toName: user.displayName ?? contact['name'] ?? '',
          plan: 'annual',
          amountPaise: 30000,
          paymentId: paymentId,
          validFrom: now2,
          validUntil: now2.add(const Duration(days: 365)),
        );
      }
      if (!mounted) return;
      setState(() => _isProcessing = false);
      widget.onPurchaseComplete();
      Navigator.pop(context);
      // Collect delivery address for printed copy
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DeliveryAddressPage(
            paymentId: paymentId,
            userName: user.displayName ?? contact['name'] ?? '',
          ),
        ),
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('🎉 वार्षिक सदस्यता सक्रिय! Payment ID: $paymentId'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    // Log full error details to terminal for debugging
    debugPrint('[Razorpay] Payment FAILED:');
    debugPrint('[Razorpay]   Code   : ${response.code}');
    debugPrint('[Razorpay]   Message: ${response.message}');
    debugPrint('[Razorpay]   Error  : ${response.error}');
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ भुगतान असफल (${response.code}): ${response.message ?? 'कृपया पुनः प्रयास करें'}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (!mounted) return;
    setState(() => _isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Wallet: ${response.walletName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Initiate Payments ────────────────────────────────────────────────────

  Future<void> _handleSinglePurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) { _showLoginSnack(); return; }

    setState(() { _isProcessing = true; _activePlan = 'single'; });

    try {
      final options = await _buildOptions(
        amountPaise: 2000, // ₹20
        description: 'एकल अंक: ${widget.edition.title}',
      );
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('भुगतान शुरू नहीं हो सका: $e')),
      );
    }
  }

  Future<void> _handleAnnualPurchase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) { _showLoginSnack(); return; }

    setState(() { _isProcessing = true; _activePlan = 'annual'; });

    try {
      final options = await _buildOptions(
        amountPaise: 30000, // ₹300
        description: 'वार्षिक सदस्यता – सभी 12 अंक + मुद्रित पत्रिका',
      );
      _razorpay.open(options);
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('भुगतान शुरू नहीं हो सका: $e')),
      );
    }
  }

  // BUG-009 FIX: Show dialog with a Login button instead of dead-end snackbar
  void _showLoginSnack() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.lock_outlined, color: AppColors.primaryRed, size: 40),
        title: const Text('लॉगिन आवश्यक', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('मैगज़ीन खरीदने के लिए कृपया पहले गूगल से साइन इन करें।', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('रद्द करें', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
            },
            child: const Text('लॉगिन करें'),
          ),
        ],
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // BUG-013 FIX: Resolve dark mode from system brightness
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;
    // UX-02 FIX: Any plan processing disables BOTH buttons
    final bool anyProcessing = _isProcessing;

    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.dividerOn(isDark),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Text(
                  'इस अंक को पढ़ने के लिए',
                  style: TextStyle(fontSize: 13, color: DesignTokens.textSecondaryOn(isDark)),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.edition.title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: DesignTokens.textPrimaryOn(isDark),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Plans
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Single Issue Card
                _PlanCard(
                  isDark: isDark,
                  badge: null,
                  title: 'एकल अंक',
                  subtitle: 'केवल ${widget.edition.title} पढ़ें',
                  price: '₹20',
                  validity: '30 दिन वैधता',
                  features: const [
                    'इस अंक का पूरा PDF',
                    'ऐप में पढ़ें',
                    '30 दिन वैधता',
                  ],
                  buttonLabel: '₹20 में खरीदें',
                  buttonColor: AppColors.primaryRed,
                  isLoading: _isProcessing && _activePlan == 'single',
                  onTap: _handleSinglePurchase,
                ),

                const SizedBox(height: 12),

                // Annual Card
                _PlanCard(
                  isDark: isDark,
                  badge: 'सबसे लोकप्रिय',
                  title: 'वार्षिक सदस्यता',
                  subtitle: 'सभी 12 अंक + घर पर डिलीवरी',
                  price: '₹300/वर्ष',
                  validity: '365 दिन वैधता',
                  features: const [
                    'सभी अंक ऐप में पढ़ें',
                    'हर माह मुद्रित प्रति घर पर',
                    'एक्सक्लूसिव सामग्री',
                    '12 महीने वैधता',
                  ],
                  buttonLabel: '₹300 में सदस्य बनें',
                  buttonColor: AppColors.accentOrange,
                  isLoading: _isProcessing && _activePlan == 'annual',
                  onTap: _handleAnnualPurchase,
                  isHighlighted: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Payment note
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              '🔒 सुरक्षित भुगतान • Razorpay द्वारा संचालित',
              style: TextStyle(fontSize: 11, color: DesignTokens.textSecondaryOn(isDark)),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 24),
        ],
      ),
    );
  }
}

// ── Plan Card Widget ─────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final bool isDark;
  final String? badge;
  final String title;
  final String subtitle;
  final String price;
  final String validity;
  final List<String> features;
  final String buttonLabel;
  final Color buttonColor;
  final bool isLoading;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _PlanCard({
    required this.isDark,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.validity,
    required this.features,
    required this.buttonLabel,
    required this.buttonColor,
    required this.isLoading,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    // If it's highlighted, the background is always dark
    // If not highlighted, the background is off-white (Colors.grey.shade50)
    final bool isDarkBackground = isHighlighted;

    return Container(
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppColors.primaryDark.withOpacity(isDark ? 0.6 : 1.0)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted ? AppColors.accentOrange : Colors.grey.shade300,
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.accentOrange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          // Use black if not highlighted (white background)
                          color: isDarkBackground ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkBackground ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      price,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: isHighlighted ? AppColors.accentOrange : buttonColor,
                      ),
                    ),
                    Text(
                      validity,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDarkBackground ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Feature bullets
            ...features.map((f) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 14,
                    color: isHighlighted ? AppColors.accentOrange : AppColors.primaryRed,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkBackground ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            )),

            const SizedBox(height: 14),

            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        buttonLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

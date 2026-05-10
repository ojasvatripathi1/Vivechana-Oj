import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';

class RefundPolicyPage extends StatelessWidget {
  const RefundPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        ),
        title: const Text(
          'धनवापसी और रद्दीकरण नीति',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            FadeInDown(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.appbarGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'धनवापसी और रद्दीकरण नीति',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'अंतिम अद्यतन: मार्च 2026',
                              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'हम धनवापसी और रद्दीकरण के संबंध में पारदर्शी नीति का पालन करते हैं। कृपया खरीदारी से पहले इसे अवश्य पढ़ें।',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.85),
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Eligible for refund
            FadeInUp(
              delay: const Duration(milliseconds: 60),
              child: _buildHighlightCard(
                isDark: isDark,
                icon: Icons.check_circle_outline_rounded,
                color: Colors.green,
                title: 'धनवापसी योग्य स्थितियाँ',
                items: [
                  'तकनीकी समस्या के कारण सामग्री एक्सेस न हो सके।',
                  'डुप्लीकेट भुगतान (एक ही अंक दो बार भुगतान)।',
                  'भुगतान कटने के बाद सदस्यता सक्रिय न हो।',
                  'वार्षिक सदस्यता में मुद्रित प्रति 30 दिन में न पहुँचे।',
                  'एप्लिकेशन की तकनीकी खराबी के कारण सेवा का लाभ न मिले।',
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Not eligible for refund
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              child: _buildHighlightCard(
                isDark: isDark,
                icon: Icons.cancel_outlined,
                color: AppColors.primaryRed,
                title: 'धनवापसी के लिए अपात्र स्थितियाँ',
                items: [
                  'सामग्री पढ़ लेने के बाद धनवापसी अनुरोध।',
                  'व्यक्तिगत पसंद या असंतोष के आधार पर।',
                  'इंटरनेट कनेक्टिविटी समस्या के कारण।',
                  'खाता नियमों का उल्लंघन करने के कारण निलंबन।',
                  'एकल अंक को PDF डाउनलोड करने के बाद।',
                ],
              ),
            ),

            const SizedBox(height: 24),

            FadeInUp(
              delay: const Duration(milliseconds: 140),
              child: _sectionLabel('सदस्यता-वार नीति', isDark),
            ),
            const SizedBox(height: 12),

            FadeInUp(
              delay: const Duration(milliseconds: 160),
              child: _planPolicyCard(
                isDark: isDark,
                title: 'एकल अंक (₹20)',
                icon: Icons.article_outlined,
                color: AppColors.primaryRed,
                policies: [
                  _PolicyItem('तकनीकी समस्या होने पर', 'पूर्ण धनवापसी', true),
                  _PolicyItem('सामग्री न खुले', 'पूर्ण धनवापसी', true),
                  _PolicyItem('पढ़ने के बाद', 'धनवापसी नहीं', false),
                  _PolicyItem('30 दिन की वैधता समाप्त', 'धनवापसी नहीं', false),
                ],
              ),
            ),

            const SizedBox(height: 12),

            FadeInUp(
              delay: const Duration(milliseconds: 180),
              child: _planPolicyCard(
                isDark: isDark,
                title: 'वार्षिक सदस्यता (₹300)',
                icon: Icons.star_outline_rounded,
                color: AppColors.accentOrange,
                policies: [
                  _PolicyItem('तकनीकी समस्या / भुगतान डुप्लीकेट', 'पूर्ण धनवापसी', true),
                  _PolicyItem('मुद्रित प्रति 30 दिन में न मिले', 'आंशिक धनवापसी या पुनः भेजना', true),
                  _PolicyItem('7 दिन के अंदर रद्दीकरण (अप्रयुक्त)', 'पूर्ण धनवापसी', true),
                  _PolicyItem('7 दिन बाद रद्दीकरण', 'धनवापसी नहीं', false),
                  _PolicyItem('वार्षिक अवधि समाप्त', 'धनवापसी नहीं', false),
                ],
              ),
            ),

            const SizedBox(height: 24),

            FadeInUp(
              delay: const Duration(milliseconds: 210),
              child: _sectionLabel('धनवापसी प्रक्रिया', isDark),
            ),
            const SizedBox(height: 12),

            FadeInUp(
              delay: const Duration(milliseconds: 230),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DesignTokens.cardColorOn(isDark),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _processStep('1', 'अनुरोध भेजें', 'vivechanaoaj@gmail.com पर ईमेल करें। भुगतान विवरण, UPI ट्रांज़ैक्शन ID / विवरण और समस्या का संक्षिप्त विवरण दें।', isDark),
                    _divider(),
                    _processStep('2', 'समीक्षा', 'हमारी टीम 3 कार्यदिवसों में आपका अनुरोध समीक्षा करेगी और ईमेल द्वारा सूचित करेगी।', isDark),
                    _divider(),
                    _processStep('3', 'धनवापसी', 'स्वीकृत धनवापसी 7–10 कार्यदिवसों में मूल भुगतान माध्यम पर वापस की जाएगी।', isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            FadeInUp(
              delay: const Duration(milliseconds: 260),
              child: _sectionLabel('रद्दीकरण', isDark),
            ),
            const SizedBox(height: 12),

            FadeInUp(
              delay: const Duration(milliseconds: 280),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: DesignTokens.cardColorOn(isDark),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bulletPoint('वार्षिक सदस्यता खरीद के 7 दिनों के भीतर रद्द की जा सकती है।', isDark),
                    _bulletPoint('रद्दीकरण के लिए vivechanaoaj@gmail.com पर "सदस्यता रद्दीकरण" विषय के साथ ईमेल करें।', isDark),
                    _bulletPoint('रद्दीकरण प्रभावी होने के बाद शेष समय के लिए धनवापसी नहीं दी जाएगी।', isDark),
                    _bulletPoint('प्रचलित छूट/ऑफर के तहत खरीदी गई सदस्यताएँ रद्दीकरण-अपात्र हो सकती हैं।', isDark),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            FadeInUp(
              delay: const Duration(milliseconds: 310),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(isDark ? 0.4 : 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'धनवापसी के किसी भी प्रश्न के लिए कृपया हमें ईमेल करें: vivechanaoaj@gmail.com\nफोन: +91-7007151488 (सोमवार–शुक्रवार, 10 AM–6 PM)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            FadeInUp(
              delay: const Duration(milliseconds: 330),
              child: Center(
                child: Text(
                  '© 2026 विवेचना-ओज पत्रिका। सर्वाधिकार सुरक्षित।',
                  style: TextStyle(
                    fontSize: 11,
                    color: DesignTokens.textSecondaryOn(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: DesignTokens.textSecondaryOn(isDark),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildHighlightCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(isDark ? 0.4 : 0.25)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  color == Colors.green ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: color,
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 13,
                      color: DesignTokens.textSecondaryOn(isDark),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _planPolicyCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color color,
    required List<_PolicyItem> policies,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: DesignTokens.cardColorOn(isDark),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOn(isDark),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: policies.asMap().entries.map((e) {
                final item = e.value;
                final last = e.key == policies.length - 1;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.condition,
                              style: TextStyle(
                                fontSize: 12,
                                color: DesignTokens.textSecondaryOn(isDark),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: item.eligible ? Colors.green.withOpacity(0.1) : AppColors.primaryRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.action,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: item.eligible ? Colors.green.shade700 : AppColors.primaryRed,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!last) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _processStep(String number, String title, String description, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: AppColors.appbarGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: DesignTokens.textPrimaryOn(isDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: DesignTokens.textSecondaryOn(isDark),
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

  Widget _divider() => const Divider(height: 1, indent: 44);

  Widget _bulletPoint(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.accentOrange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: DesignTokens.textSecondaryOn(isDark),
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyItem {
  final String condition;
  final String action;
  final bool eligible;
  const _PolicyItem(this.condition, this.action, this.eligible);
}

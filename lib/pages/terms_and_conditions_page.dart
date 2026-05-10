import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../config/design_tokens.dart';
import '../constants/app_colors.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

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
          'नियम और शर्तें',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                  color: AppColors.primaryDark.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primaryDark.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.appbarGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'नियम और शर्तें',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DesignTokens.textPrimaryOn(isDark),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'अंतिम अद्यतन: मार्च 2026',
                            style: TextStyle(
                              fontSize: 12,
                              color: DesignTokens.textSecondaryOn(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            FadeInUp(
              delay: const Duration(milliseconds: 30),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'विवेचना-ओज ("हम", "हमारी", "एप्लिकेशन") द्वारा प्रदान की जाने वाली सेवाओं का उपयोग करके आप निम्नलिखित नियमों और शर्तों से सहमत होते हैं। कृपया इन्हें ध्यान से पढ़ें।',
                  style: TextStyle(
                    fontSize: 13,
                    color: DesignTokens.textSecondaryOn(isDark),
                    height: 1.6,
                  ),
                ),
              ),
            ),

            _buildSection(
              delay: 60,
              number: '1',
              title: 'सेवाओं का उपयोग',
              isDark: isDark,
              content: [
                'इस एप्लिकेशन का उपयोग केवल वैध और कानूनी उद्देश्यों के लिए किया जाना चाहिए।',
                '18 वर्ष से कम आयु के उपयोगकर्ताओं को अभिभावक की अनुमति से उपयोग करना अनिवार्य है।',
                'आप अपने खाते की सुरक्षा के लिए स्वयं जिम्मेदार हैं।',
                'एक साथ एकाधिक खातों का उपयोग प्रतिबंधित है।',
              ],
            ),

            _buildSection(
              delay: 90,
              number: '2',
              title: 'सदस्यता और भुगतान',
              isDark: isDark,
              content: [
                'एकल अंक सदस्यता: ₹20 प्रति अंक (30 दिन वैधता)।',
                'वार्षिक सदस्यता: ₹300 प्रति वर्ष (12 अंक + घर पर मुद्रित प्रति)।',
                'भुगतान सफल होने पर तुरंत सेवा सक्रिय होती है।',
                'सदस्यता के दौरान मूल्य में कोई वृद्धि नहीं होगी।',
                'सभी भुगतान Razorpay पेमेंट गेटवे के माध्यम से सुरक्षित रूप से संसाधित किए जाते हैं।',
              ],
            ),

            _buildSection(
              delay: 120,
              number: '3',
              title: 'बौद्धिक संपदा अधिकार',
              isDark: isDark,
              content: [
                'विवेचना-ओज पर प्रकाशित सभी लेख, चित्र, लोगो और सामग्री हमारे स्वामित्व में हैं।',
                'बिना लिखित अनुमति के किसी भी सामग्री का पुनर्प्रकाशन या वितरण प्रतिबंधित है।',
                'व्यक्तिगत उपयोग हेतु सामग्री साझा करना अनुमत है।',
                'लेखकों की रचनाएँ प्रकाशन के बाद विवेचना-ओज के साथ संयुक्त रूप से स्वामित्व में होती हैं।',
              ],
            ),

            _buildSection(
              delay: 150,
              number: '4',
              title: 'लेखक नीति',
              isDark: isDark,
              content: [
                'लेखक पंजीकरण के लिए आधार कार्ड और मोबाइल नंबर की अद्वितीयता आवश्यक है।',
                'सभी रचनाएँ मौलिक होनी चाहिए — साहित्यिक चोरी पूर्णतः प्रतिबंधित है।',
                'प्रकाशन के लिए प्रस्तुत सामग्री समीक्षा के बाद ही स्वीकृत की जाएगी।',
                'आपत्तिजनक, भड़काऊ या असत्य सामग्री प्रस्तुत करने पर खाता निलंबित किया जा सकता है।',
                'अस्वीकृत रचनाओं का कारण लेखक को सूचित किया जाएगा।',
              ],
            ),

            _buildSection(
              delay: 180,
              number: '5',
              title: 'गोपनीयता नीति',
              isDark: isDark,
              content: [
                'हम आपका नाम, ईमेल, फोन नंबर और उपयोग डेटा संग्रहित करते हैं।',
                'आपकी व्यक्तिगत जानकारी किसी तृतीय पक्ष को विक्रय नहीं की जाती।',
                'डेटा केवल सेवा सुधार और उपयोगकर्ता अनुभव के लिए उपयोग किया जाता है।',
                'Firebase जैसी विश्वसनीय तृतीय-पक्ष सेवाएँ डेटा संग्रह में शामिल हैं।',
              ],
            ),

            _buildSection(
              delay: 210,
              number: '6',
              title: 'टिप्पणियाँ और उपयोगकर्ता सामग्री',
              isDark: isDark,
              content: [
                'केवल पंजीकृत उपयोगकर्ता ही टिप्पणियाँ कर सकते हैं।',
                'अनामिक उपयोगकर्ताओं को टिप्पणी करने की अनुमति नहीं है।',
                'अभद्र, सांप्रदायिक या भड़काऊ टिप्पणियाँ हटाई जा सकती हैं।',
                'उपयोगकर्ता की टिप्पणी सामग्री के लिए वे स्वयं उत्तरदायी हैं।',
              ],
            ),

            _buildSection(
              delay: 240,
              number: '7',
              title: 'सेवा समाप्ति',
              isDark: isDark,
              content: [
                'नियमों के उल्लंघन पर हम किसी भी खाते को निलंबित या समाप्त करने का अधिकार सुरक्षित रखते हैं।',
                'हम बिना पूर्व सूचना के सेवाओं में परिवर्तन करने का अधिकार रखते हैं।',
                'सेवा बाधा की स्थिति में हम उचित मुआवजा प्रदान करने का प्रयास करेंगे।',
              ],
            ),

            _buildSection(
              delay: 270,
              number: '8',
              title: 'विवाद समाधान',
              isDark: isDark,
              content: [
                'किसी भी विवाद के मामले में पहले vivechanaoaj@gmail.com पर लिखित शिकायत दर्ज करें।',
                'सभी विवाद भारतीय कानून के अंतर्गत हमीरपुर, उत्तर प्रदेश की अदालत के अधिकार क्षेत्र में आएंगे।',
                'विवाद समाधान के लिए 30 दिन की अवधि में प्रतिक्रिया दी जाएगी।',
              ],
            ),

            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryRed.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primaryRed, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'इन नियमों में परिवर्तन की स्थिति में ऐप में सूचना दी जाएगी। अद्यतन नियमों से असहमति पर खाता बंद किया जा सकता है।',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryRed.withOpacity(0.85),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            FadeInUp(
              delay: const Duration(milliseconds: 320),
              child: Center(
                child: Column(
                  children: [
                    Text(
                      'प्रश्नों के लिए संपर्क करें:',
                      style: TextStyle(fontSize: 12, color: DesignTokens.textSecondaryOn(isDark)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'vivechanaoaj@gmail.com',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),
            FadeInUp(
              delay: const Duration(milliseconds: 340),
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

  Widget _buildSection({
    required int delay,
    required String number,
    required String title,
    required List<String> content,
    required bool isDark,
  }) {
    return FadeInUp(
      delay: Duration(milliseconds: delay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            // Section header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.04),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: AppColors.appbarGradient,
                      borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(width: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.textPrimaryOn(isDark),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: content.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryRed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 13,
                            color: DesignTokens.textSecondaryOn(isDark),
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

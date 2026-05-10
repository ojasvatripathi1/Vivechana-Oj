import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({super.key});

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedSubject;
  final TextEditingController _messageController = TextEditingController();

  bool _isSubmitting = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label कॉपी हो गया'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF8B4513),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('लिंक खोलने में समस्या हुई')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('लिंक खोलने में समस्या हुई')),
        );
      }
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSubject == null || _selectedSubject!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('कृपया विषय चुनें'),
            backgroundColor: Color(0xFFDAA520),
          ),
        );
        return;
      }
      
      setState(() {
        _isSubmitting = true;
      });
      
      try {
        final response = await http.post(
          Uri.parse('https://formspree.io/f/mkoqgeko'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'name': _nameController.text,
            'email': _emailController.text,
            'phone': _phoneController.text,
            'subject': _selectedSubject,
            'message': _messageController.text,
            '_subject': 'नई संपर्क प्रतिक्रिया - विवेचना ओज',
          }),
        );
        
        setState(() {
          _isSubmitting = false;
        });

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('आपका संदेश सफलतापूर्वक भेज दिया गया है। हम जल्द ही आपसे संपर्क करेंगे।'),
                backgroundColor: Color(0xFF8B4513),
                behavior: SnackBarBehavior.floating,
              ),
            );
            
            // Reset form
            _nameController.clear();
            _emailController.clear();
            _phoneController.clear();
            _messageController.clear();
            setState(() {
              _selectedSubject = null;
            });
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('संदेश भेजने में विफल। कृपया फिर से प्रयास करें।'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isSubmitting = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('नेटवर्क त्रुटि। कृपया अपने इंटरनेट कनेक्शन की जाँच करें।'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF8B4513), size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121212) : null,
          gradient: isDark ? null : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF5F0E6), Color(0xFFE8D9C5)],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 20,
            bottom: 40,
            left: 20,
            right: 20,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFC8AA8C).withOpacity(0.3),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isDesktop = constraints.maxWidth >= 700;
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        if (isDesktop)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 1, child: _buildInfoPanel()),
                                Expanded(flex: 2, child: _buildFormPanel()),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              _buildInfoPanel(),
                              _buildFormPanel(),
                            ],
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 30),
      decoration: const BoxDecoration(
        color: Color(0xFF8B4513),
        border: Border(bottom: BorderSide(color: Color(0xFFDAA520), width: 5)),
      ),
      child: Center(
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[800] : Colors.white,
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/app_logo.png', // Fallback, update if there's a different asset path
                height: 50,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.menu_book, size: 50, color: Color(0xFF8B4513)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'विवेचना ओज',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD700),
                    letterSpacing: 2.0,
                    shadows: [
                      Shadow(
                        color: Color(0xFF5A3E1B),
                        offset: Offset(2, 2),
                        blurRadius: 0,
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'हिंदी पत्रिका',
                  style: TextStyle(
                    fontSize: 16,
                    letterSpacing: 3.0,
                    color: const Color(0xFFF5DEB3),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoPanel() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFDF8F0),
        border: Border(
          right: MediaQuery.of(context).size.width >= 700 
              ? const BorderSide(color: Color(0xFFDAA520), width: 2, style: BorderStyle.solid) // using solid since dashed isn't native without custom painter
              : BorderSide.none,
          bottom: MediaQuery.of(context).size.width < 700
              ? const BorderSide(color: Color(0xFFDAA520), width: 2, style: BorderStyle.solid)
              : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInLeft(
            child: _buildSectionTitle('📬 संपर्क करें'),
          ),
          const SizedBox(height: 25),
          FadeInLeft(
            delay: const Duration(milliseconds: 100),
            child: Text(
              'आपके विचार, सुझाव और रचनाएँ हमारे लिए महत्वपूर्ण हैं। \nकृपया नीचे दिए गए फ़ॉर्म के माध्यम से हमसे जुड़ें।',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.white70 : const Color(0xFF3E2C1B),
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 30),
          FadeInLeft(
            delay: const Duration(milliseconds: 200),
            child: _buildDetailItem(
              icon: Icons.email_rounded,
              text: 'vivechanaoaj@gmail.com',
              onTap: () => _copyToClipboard('vivechanaoaj@gmail.com', 'ईमेल'),
            ),
          ),
          const SizedBox(height: 20),
          FadeInLeft(
            delay: const Duration(milliseconds: 300),
            child: _buildDetailItem(
              icon: Icons.phone_rounded,
              text: '+91 7007151488',
              onTap: () => _copyToClipboard('+917007151488', 'फोन नंबर'),
            ),
          ),
          const SizedBox(height: 20),
          FadeInLeft(
            delay: const Duration(milliseconds: 400),
            child: _buildDetailItem(
              icon: Icons.location_on_rounded,
              text: 'आनंद कुटी, नेशनल रोड मौदहा - हमीरपुर, 210507',
              onTap: () => _copyToClipboard('आनंद कुटी, नेशनल रोड मौदहा - हमीरपुर, 210507', 'पता'),
            ),
          ),
          const SizedBox(height: 40),
          FadeInLeft(
            delay: const Duration(milliseconds: 500),
            child: Text(
              'हमें फॉलो करें',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFDAA520) : const Color(0xFF8B4513),
              ),
            ),
          ),
          const SizedBox(height: 15),
          FadeInLeft(
            delay: const Duration(milliseconds: 600),
            child: Row(
              children: [
                _buildSocialIcon(Icons.facebook, 'https://facebook.com'),
                const SizedBox(width: 15),
                _buildSocialIcon(Icons.camera_alt, 'https://instagram.com/vivechanaoj?igsh=d3U0czcwaTF6ZnVz'),
                const SizedBox(width: 15),
                _buildSocialIcon(Icons.play_arrow_rounded, 'https://youtube.com'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormPanel() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 35),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFFFFCF7),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInRight(
              child: _buildSectionTitle('✉️ संदेश भेजें', fontSize: 26),
            ),
            const SizedBox(height: 10),
            FadeInRight(
              delay: const Duration(milliseconds: 100),
              child: Text(
                'सभी फ़ील्ड अनिवार्य हैं',
                style: TextStyle(
                  color: isDark ? Colors.white70 : const Color(0xFF5A3E1B),
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 25),
            FadeInUp(
              delay: const Duration(milliseconds: 200),
              child: _buildTextField(
                label: 'आपका नाम *',
                hintText: 'उदा.: राम कुमार',
                controller: _nameController,
                validator: (value) =>
                    value == null || value.isEmpty ? 'कृपया अपना नाम दर्ज करें' : null,
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 300),
              child: _buildTextField(
                label: 'ईमेल पता *',
                hintText: 'aapka@email.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'कृपया अपना ईमेल दर्ज करें';
                  }
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'कृपया वैध ईमेल दर्ज करें';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: _buildTextField(
                label: 'फ़ोन नंबर (वैकल्पिक)',
                hintText: '9876543210',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'विषय *',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : const Color(0xFF5A3E1B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedSubject,
                    dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF3E2C1B), fontSize: 16),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: isDark ? Colors.grey[900] : const Color(0xFFFFFDF9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFEADBC6), width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFDAA520), width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('-- चुनें --')),
                      const DropdownMenuItem(value: 'पाठक की राय', child: Text('पाठक की राय')),
                      const DropdownMenuItem(value: 'लेख/कविता प्रस्तुत करें', child: Text('लेख/कविता प्रस्तुत करें')),
                      const DropdownMenuItem(value: 'विज्ञापन', child: Text('विज्ञापन')),
                      const DropdownMenuItem(value: 'सहयोग', child: Text('सहयोग')),
                      const DropdownMenuItem(value: 'अन्य', child: Text('अन्य')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedSubject = val;
                      });
                    },
                    validator: (value) => value == null || value.isEmpty ? 'कृपया विषय चुनें' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              delay: const Duration(milliseconds: 600),
              child: _buildTextField(
                label: 'आपका संदेश *',
                hintText: 'यहाँ लिखें...',
                controller: _messageController,
                maxLines: 5,
                validator: (value) =>
                    value == null || value.isEmpty ? 'कृपया अपना संदेश दर्ज करें' : null,
              ),
            ),
            const SizedBox(height: 30),
            FadeInUp(
              delay: const Duration(milliseconds: 700),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: const Color(0xFFFFD700),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0, // Using manual border bottom
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>((Set<WidgetState> states) {
                      if (states.contains(WidgetState.disabled)) return Colors.grey;
                      return const Color(0xFF8B4513);
                    }),
                  ),
                  child: Container(
                    padding: const EdgeInsets.only(bottom: 2), // for the "border-bottom" look
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Color(0xFF5A3E1B),
                          width: 3.0,
                        ),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Color(0xFFFFD700),
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '📨 संदेश भेजें',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 25),
            FadeInUp(
              delay: const Duration(milliseconds: 800),
              child: const Center(
                child: Text(
                  'हम 24-48 घंटों के भीतर आपको जवाब देंगे। धन्यवाद!',
                  style: TextStyle(
                    color: Color(0xFF8B6B4D),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {double fontSize = 28}) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.only(bottom: 5),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFDAA520), width: 3),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : const Color(0xFF8B4513),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: const Color(0xFFDAA520),
              shape: BoxShape.circle,
              boxShadow: const [
                 BoxShadow(
                  color: Color(0xFFB8860B),
                  blurRadius: 0,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF8B4513), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF2C1E0F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF5A3E1B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 16,
            color: isDark ? Colors.white : const Color(0xFF3E2C1B),
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? Colors.white30 : const Color(0xFF3E2C1B).withOpacity(0.5),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[900] : const Color(0xFFFFFDF9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white12 : const Color(0xFFEADBC6), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDAA520), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          color: const Color(0xFF8B4513),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFDAA520), width: 2),
        ),
        child: Icon(icon, color: const Color(0xFFFFD700), size: 24),
      ),
    );
  }
}

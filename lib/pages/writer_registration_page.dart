import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/storage_service.dart';

class WriterRegistrationPage extends StatefulWidget {
  const WriterRegistrationPage({super.key});

  @override
  State<WriterRegistrationPage> createState() => _WriterRegistrationPageState();
}

class _WriterRegistrationPageState extends State<WriterRegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _penNameController = TextEditingController(); // Upnaam
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _publicationsController = TextEditingController();
  final _aadharController = TextEditingController();

  // Selected state
  final List<String> _availableGenres = ['कविता', 'ग़ज़ल', 'कहानी', 'उपन्यास', 'लेख'];
  final List<String> _selectedGenres = [];
  String? _selectedGender;
  
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  
  // OTP Verification State
  String? _verificationId;
  bool _phoneVerified = false;
  bool _isVerifying = false;
  int? _resendToken;

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    // BUG-008 FIX: Indian mobile numbers must start with 6-9 and be exactly 10 digits
    final phoneRegex = RegExp(r'^[6-9]\d{9}$');
    if (!phoneRegex.hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कृपया सही मोबाइल नंबर दर्ज करें (6-9 से शुरू, 10 अंक)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Check uniqueness before sending OTP so we don't waste Firebase quota
      final phoneQuery = await FirebaseFirestore.instance
           .collection('writer_registrations')
           .where('phone', isEqualTo: phone)
           .limit(1)
           .get();
           
      if (phoneQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('क्षमा करें, यह मोबाइल नंबर पहले से पंजीकृत है।'), backgroundColor: Colors.red),
          );
          setState(() => _isVerifying = false);
        }
        return;
      }

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+91$phone', // Assuming India formatting
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-resolution on Android
          await _linkCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _isVerifying = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('सत्यापन विफल: ${e.message}'), backgroundColor: Colors.red),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _resendToken = resendToken;
              _isVerifying = false;
            });
            _showOtpBottomSheet();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _isVerifying = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OTP भेजने में त्रुटि: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showOtpBottomSheet() {
    final otpController = TextEditingController();
    bool isSubmittingOtp = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24, right: 24, top: 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('OTP दर्ज करें', style: GoogleFonts.notoSansDevanagari(fontSize: 22, fontWeight: FontWeight.bold, color: DesignTokens.textPrimaryOn(Theme.of(context).brightness == Brightness.dark))),
                  const SizedBox(height: 8),
                  Text(
                    '${_phoneController.text.trim()} पर भेजा गया 6 अंकों का कोड दर्ज करें',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark), fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold, color: DesignTokens.textPrimaryOn(Theme.of(context).brightness == Brightness.dark)),
                    decoration: InputDecoration(
                      hintText: '000000',
                      hintStyle: TextStyle(color: DesignTokens.textSecondaryOn(Theme.of(context).brightness == Brightness.dark)),
                      counterText: '',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade800 : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: isSubmittingOtp ? null : () async {
                        final code = otpController.text.trim();
                        if (code.length == 6 && _verificationId != null) {
                          setModalState(() => isSubmittingOtp = true);
                          try {
                            final credential = PhoneAuthProvider.credential(
                              verificationId: _verificationId!,
                              smsCode: code,
                            );
                            await _linkCredential(credential);
                            if (mounted) Navigator.pop(ctx);
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => isSubmittingOtp = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('अमान्य OTP'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        }
                      },
                      child: isSubmittingOtp
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('सत्यापित करें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          }
        );
      },
      backgroundColor: DesignTokens.scaffoldOn(Theme.of(context).brightness == Brightness.dark),
    );
  }

  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Try linking the phone credential to the existing email/Google auth user
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          // If the phone is already linked to another account, we might get credential-already-in-use.
          // For now, depending on app rules, we could ignore or warn. 
          // Since we just need to verify they own the number NOW, we can just mark it verified locally 
          // even if the Firebase link fails, as long as the OTP was correct.
          // But linking is safer.
          if (e.code == 'provider-already-linked') {
             // Already linked to this user, fine.
          } else if (e.code == 'credential-already-in-use') {
             // Let it pass validation for registration purposes, or reject it.
             // We'll let it pass locally so they can register.
             debugPrint('Phone already in use by another Firebase account: $e');
          } else {
             rethrow;
          }
        }
      }
      if (mounted) {
        setState(() {
          _phoneVerified = true;
          _isVerifying = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('मोबाइल नंबर सफलतापूर्वक सत्यापित हो गया!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error linking credential: $e');
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('सत्यापन विफल हुआ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 70,
        maxWidth: 1080,
        maxHeight: 1080,
      );
      if (image != null) {
        final file = File(image.path);
        final CroppedFile? croppedFile = await ImageCropper().cropImage(
          sourcePath: image.path,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop for profile
          uiSettings: [
             AndroidUiSettings(
              toolbarTitle: 'क्रॉप इमेज',
              toolbarColor: AppColors.primaryRed,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: 'क्रॉप इमेज',
              aspectRatioLockEnabled: true,
            ),
          ],
        );

        if (croppedFile != null) {
          setState(() {
            _profileImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _penNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _publicationsController.dispose();
    _aadharController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      try {
        final phone = _phoneController.text.trim();
        final aadhar = _aadharController.text.trim();
        
        if (!_phoneVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('कृपया पहले अपना मोबाइल नंबर सत्यापित करें।'), backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
          return;
        }

        // --- UNIQUENESS VALIDATION ---
        
        // Check for existing Aadhar Number
        if (aadhar.isNotEmpty) {
           final aadharQuery = await FirebaseFirestore.instance
               .collection('writer_registrations')
               .where('aadharNumber', isEqualTo: aadhar)
               .limit(1)
               .get();
               
           if (aadharQuery.docs.isNotEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('क्षमा करें, यह आधार नंबर पहले से पंजीकृत है।'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
              setState(() => _isSaving = false);
              return;
           }
        }

        String? profileImageUrl;

        // 1. Upload Profile Picture to Firebase Storage (if selected)
        if (_profileImage != null) {
          try {
            // Force-refresh the auth token after phone verification
            // This is necessary because after OTP linking the old anonymous
            // token is still cached — Storage rejects it with 403 until refreshed.
            final user = FirebaseAuth.instance.currentUser;
            await user?.getIdToken(true);
            final uid = user?.uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
            debugPrint('[Registration] Uploading photo, uid=$uid, auth=${user != null}');
            profileImageUrl = await StorageService.uploadProfilePhoto(
              file: _profileImage!,
              storagePath: 'writer_profiles/$uid.jpg',
            );
          } catch (uploadError) {
            debugPrint('Image Upload Error: $uploadError');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('चेतावनी: प्रोफ़ाइल फ़ोटो अपलोड नहीं हो सकी।'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 4),
                ),
              );
            }
            // Continue with registration even if photo fails
          }
        }

        // 2. Prepare Registration Data
        final currentUser = FirebaseAuth.instance.currentUser;
        final applicationData = {
          'uid': currentUser?.uid,
          'fullName': _fullNameController.text.trim(),
          'penName': _penNameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender,
          'bio': _bioController.text.trim(),
          'preferredGenres': _selectedGenres,
          'previousPublications': _publicationsController.text.trim(),
          'aadharNumber': _aadharController.text.trim(),
          'profileImageUrl': profileImageUrl,
          'status': 'pending', // Requires admin approval
          'submittedAt': FieldValue.serverTimestamp(),
        };

        // 3. Save to Firestore (writer_registrations collection)
        final docRef = await FirebaseFirestore.instance
            .collection('writer_registrations')
            .add(applicationData);

        // 4. Send Email via Native Email App
        final String subject = Uri.encodeComponent('विवेचना-ओज - नया लेखक पंजीकरण: ${_fullNameController.text.trim()}');
        final String body = Uri.encodeComponent('''
नमस्कार टीम,

मुझे विवेचना-ओज में एक लेखक के रूप में शामिल होने में रुचि है। मेरा विवरण इस प्रकार है:

- पूरा नाम: ${_fullNameController.text.trim()}
- उपनाम (Pen Name): ${_penNameController.text.trim().isNotEmpty ? _penNameController.text.trim() : 'लागू नहीं'}
- लिंग (Gender): ${_selectedGender ?? 'N/A'}
- ईमेल: ${_emailController.text.trim()}
- फ़ोन: ${_phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : 'लागू नहीं'}
- आधार नंबर: ${_aadharController.text.trim()}
- पसंदीदा विधाएं: ${_selectedGenres.join(', ')}

परिचय (Bio):
${_bioController.text.trim()}

पिछली प्रकाशित रचनाएँ:
${_publicationsController.text.trim().isNotEmpty ? _publicationsController.text.trim() : 'कोई नहीं'}

(ऑटोमेटेड आईडी: ${docRef.id})
''');

        final String userEmail = _emailController.text.trim();
        final Uri emailUri = Uri.parse('mailto:vivechanaoaj@gmail.com?cc=$userEmail&subject=$subject&body=$body');

        if (!mounted) return;
        
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 8),
                Text('आवेदन जमा हुआ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            content: const Text(
              'आपका आवेदन सफलतापूर्वक जमा हो गया है और समीक्षा के लिए एडमिन को भेज दिया गया है। मंजूरी मिलने के बाद आप लेख प्रकाशित कर सकेंगे।\n\nकृपया जनरेट किया गया ईमेल भी भेजें।',
              style: TextStyle(fontSize: 15, height: 1.4),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ठीक है (OK)', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        );
        
        if (!mounted) return;
        Navigator.pop(context); // Go back to Home Page

        // Launch the email app
        if (await canLaunchUrl(emailUri)) {
          await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch email client');
        }

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submittting application: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = DesignTokens.textPrimaryOn(isDark);
    final hintColor = DesignTokens.textSecondaryOn(isDark);

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        ),
        title: Text(
          'लेखक पंजीकरण',
          style: GoogleFonts.notoSansDevanagari(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shadowColor: Colors.black26,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'विवेचना-ओज से जुड़ें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'हमारे प्लेटफ़ॉर्म पर एक आधिकारिक लेखक बनने के लिए कृपया नीचे दिया गया फ़ॉर्म भरें।',
                  style: TextStyle(
                    fontSize: 14,
                    color: hintColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // ── Profile Picture Outline ──
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.3), width: 2),
                            image: _profileImage != null
                                ? DecorationImage(
                                    image: FileImage(_profileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profileImage == null
                              ? Icon(Icons.add_a_photo_outlined, size: 36, color: hintColor)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: AppColors.primaryRed,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'प्रोफ़ाइल फ़ोटो अपलोड करें\n(वैकल्पिक)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: hintColor),
                  ),
                ),
                const SizedBox(height: 32),

                // ── Common Fields ──
                _buildSectionTitle('व्यक्तिगत जानकारी', isDark),
                
                _buildTextField(
                  controller: _fullNameController,
                  label: 'पूरा नाम (Full Name)',
                  icon: Icons.person_outline,
                  isDark: isDark,
                  validator: (value) => value == null || value.isEmpty ? 'कृपया अपना पूरा नाम दर्ज करें' : null,
                ),
                
                _buildTextField(
                  controller: _penNameController,
                  label: 'उपनाम (Pen Name) - वैकल्पिक',
                  icon: Icons.badge_outlined,
                  isDark: isDark,
                ),

                _buildTextField(
                  controller: _emailController,
                  label: 'ईमेल पता (Email)',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'कृपया ईमेल दर्ज करें';
                    if (!value.contains('@')) return 'कृपया वैध ईमेल दर्ज करें';
                    return null;
                  },
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    dropdownColor: isDark ? DesignTokens.cardColorOn(isDark) : Colors.white,
                    style: TextStyle(color: DesignTokens.textPrimaryOn(isDark)),
                    decoration: InputDecoration(
                      labelText: 'लिंग (Gender) *',
                      labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
                      prefixIcon: Icon(Icons.wc_outlined, color: AppColors.primaryRed.withOpacity(0.7), size: 20),
                      filled: true,
                      fillColor: isDark ? DesignTokens.cardColorOn(isDark) : Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
                    ),
                    items: ['पुरुष', 'महिला', 'अन्य'].map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedGender = newValue;
                      });
                    },
                    validator: (value) => value == null ? 'कृपया अपना लिंग चुनें' : null,
                  ),
                ),

                // ── Phone Verification Row ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          readOnly: _phoneVerified,
                          style: TextStyle(color: DesignTokens.textPrimaryOn(isDark)),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'फ़ोन नंबर आवश्यक है';
                            if (value.length < 10) return 'वैध नंबर दर्ज करें';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'फ़ोन नंबर (Phone)',
                            labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
                            prefixText: '+91 ',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryRed.withOpacity(0.7), size: 20),
                            counterText: '',
                            filled: true,
                            fillColor: _phoneVerified 
                              ? (isDark ? Colors.grey.shade800 : Colors.grey.shade100) 
                              : (isDark ? DesignTokens.cardColorOn(isDark) : Colors.white),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 56, // Match text field height roughly
                        decoration: BoxDecoration(
                          color: _phoneVerified ? Colors.green.shade50 : AppColors.primaryRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _phoneVerified ? Colors.green : AppColors.primaryRed.withOpacity(0.3)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: (_phoneVerified || _isVerifying) ? null : _sendOtp,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Center(
                                child: _isVerifying 
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
                                  : _phoneVerified
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : const Text('सत्यापित\nकरें', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _buildSectionTitle('लेखन प्रोफ़ाइल', isDark),

                _buildTextField(
                  controller: _bioController,
                  label: 'अपने बारे में लिखें (Bio) *',
                  icon: Icons.person_outline,
                  hint: 'उदाहरण: मैं पिछले 5 वर्षों से हिंदी कविता और कहानी लेख रहा/रही हूँ। मेरी रचनाएँ मुख्यतः सामाजिक विषयों पर आधारित हैं...',
                  maxLines: 5,
                  maxLength: 500,
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'कृपया अपना परिचय दें — यह आपके प्रोफ़ाइल पर दिखेगा।';
                    }
                    if (value.trim().length < 50) {
                      return 'परिचय कम से कम 50 अक्षरों का होना चाहिए (अभी: ${value.trim().length})';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),
                Text(
                  'पसंदीदा विधाएं (Preferred Genres) - वैकल्पिक',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _availableGenres.map((genre) {
                    final isSelected = _selectedGenres.contains(genre);
                    return FilterChip(
                      label: Text(genre),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedGenres.add(genre);
                          } else {
                            _selectedGenres.remove(genre);
                          }
                        });
                      },
                      selectedColor: AppColors.primaryRed.withOpacity(0.15),
                      checkmarkColor: AppColors.primaryRed,
                      labelStyle: TextStyle(
                        color: isSelected ? AppColors.primaryRed : hintColor,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryRed : (Colors.black12),
                      ),
                      backgroundColor: Colors.transparent,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                _buildTextField(
                  controller: _publicationsController,
                  label: 'पिछली प्रकाशित रचनाएँ - वैकल्पिक',
                  icon: Icons.library_books_outlined,
                  hint: 'किताबों, ब्लॉग्स या लेखों के शीर्षक या लिंक...',
                  maxLines: 3,
                  isDark: isDark,
                ),

                const SizedBox(height: 12),
                _buildSectionTitle('सत्यापन (Verification)', isDark),

                _buildTextField(
                  controller: _aadharController,
                  label: 'आधार नंबर (Aadhar)',
                  icon: Icons.credit_card_outlined,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  hint: '12 अंकों का आधार नंबर',
                  isDark: isDark,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'सत्यापन के लिए आधार नंबर आवश्यक है';
                    if (value.length != 12 || int.tryParse(value) == null) return 'वैध 12 अंकों का आधार नंबर दर्ज करें';
                    return null;
                  },
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    '* आधार नंबर को बाद में बदला नहीं जा सकता है, कृपया इसे ध्यान से भरें।',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isSaving || !_phoneVerified) ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _phoneVerified ? AppColors.primaryLight : Colors.grey.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            !_phoneVerified ? 'पहले फ़ोन सत्यापित करें' : 'पंजीकरण सबमिट करें',
                            style: GoogleFonts.notoSansDevanagari(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 12),
      child: Text(
        title,
        style: GoogleFonts.notoSansDevanagari(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryRed,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final bgColor = isDark ? DesignTokens.cardColorOn(isDark) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.black12;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: TextFormField(
        controller: controller,
        style: TextStyle(color: DesignTokens.textPrimaryOn(isDark)),
        maxLines: maxLines,
        maxLength: maxLength,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
          hintText: hint,
          hintStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.5), fontSize: 13),
          prefixIcon: maxLines == 1 ? Icon(icon, color: AppColors.primaryRed.withOpacity(0.7), size: 20) : null,
          filled: true,
          fillColor: bgColor,
          focusColor: AppColors.primaryRed,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.red.shade300, width: 1.5),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/storage_service.dart';

class WriterEditProfilePage extends StatefulWidget {
  const WriterEditProfilePage({super.key});

  @override
  State<WriterEditProfilePage> createState() => _WriterEditProfilePageState();
}

class _WriterEditProfilePageState extends State<WriterEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _penNameController = TextEditingController(); // Upnaam
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _publicationsController = TextEditingController();
  final _aadharController = TextEditingController(); // Read-only typically, but we'll show it

  // Selected state
  final List<String> _availableGenres = ['कविता', 'ग़ज़ल', 'कहानी', 'उपन्यास', 'लेख'];
  List<String> _selectedGenres = [];
  String? _selectedGender;
  
  File? _newProfileImage;
  String? _existingProfileImageUrl;
  final ImagePicker _picker = ImagePicker();

  bool _isLoadingData = true;
  bool _isSaving = false;
  String? _registrationDocId; // Need this to update the exact doc

  // OTP Verification State
  String _originalPhone = '';
  String? _verificationId;
  bool _phoneVerified = true;
  bool _isVerifying = false;
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _loadWriterData();
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onPhoneChanged() {
    final currentPhone = _phoneController.text.trim();
    if (currentPhone == _originalPhone) {
      if (!_phoneVerified) setState(() => _phoneVerified = true);
    } else {
      if (_phoneVerified) setState(() => _phoneVerified = false);
    }
  }

  Future<void> _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सही मोबाइल नंबर दर्ज करें (10 अंक)'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isVerifying = true);

    try {
      // Check uniqueness before sending OTP so we don't waste Firebase quota
      final phoneQuery = await FirebaseFirestore.instance
           .collection('writer_registrations')
           .where('phone', isEqualTo: phone)
           .get();
           
      final isDuplicate = phoneQuery.docs.any((doc) => doc.id != _registrationDocId);
      if (isDuplicate) {
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
                  Text('OTP दर्ज करें', style: GoogleFonts.notoSansDevanagari(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    '${_phoneController.text.trim()} पर भेजा गया 6 अंकों का कोड दर्ज करें',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      filled: true,
                      fillColor: Colors.grey.shade100,
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
    );
  }

  Future<void> _linkCredential(PhoneAuthCredential credential) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
             // Already linked to this user, fine.
          } else if (e.code == 'credential-already-in-use') {
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

  Future<void> _loadWriterData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingData = false);
        return;
      }

      // Fetch the registration doc
      final snapshot = await FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final doc = snapshot.docs.first;
        _registrationDocId = doc.id;
        final data = doc.data();

        _fullNameController.text = data['fullName'] ?? '';
        _penNameController.text = data['penName'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        _originalPhone = data['phone'] ?? '';
        _phoneController.text = _originalPhone;
        _bioController.text = data['bio'] ?? '';
        _selectedGender = data['gender'];
        _publicationsController.text = data['previousPublications'] ?? '';
        
        final String rawAadhar = data['aadharNumber'] ?? '';
        if (rawAadhar.length >= 4) {
          _aadharController.text = '********${rawAadhar.substring(rawAadhar.length - 4)}';
        } else {
          _aadharController.text = rawAadhar;
        }
        
        _existingProfileImageUrl = data['profileImageUrl'];
        
        if (data['preferredGenres'] != null) {
          _selectedGenres = List<String>.from(data['preferredGenres']);
        }
      }
    } catch (e) {
      debugPrint('Error loading writer data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
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
            _newProfileImage = File(croppedFile.path);
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _deleteOldProfileImage(String imageUrl) async {
    // Silently delete old profile image from Firebase Storage
    await StorageService.deleteByUrl(imageUrl);
  }

  @override
  void dispose() {
    _phoneController.removeListener(_onPhoneChanged);
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
    if (_formKey.currentState!.validate() && _registrationDocId != null) {
      setState(() => _isSaving = true);

      try {
        final phone = _phoneController.text.trim();
        final aadhar = _aadharController.text.trim();
        final user = FirebaseAuth.instance.currentUser;
        
        if (!_phoneVerified) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('कृपया अपना नया फ़ोन नंबर सत्यापित करें।'), backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
          return;
        }
        
        // --- UNIQUENESS VALIDATION (excluding current user's doc) ---
        if (phone.isNotEmpty) {
           final phoneQuery = await FirebaseFirestore.instance
               .collection('writer_registrations')
               .where('phone', isEqualTo: phone)
               .get();
               
           final isDuplicate = phoneQuery.docs.any((doc) => doc.id != _registrationDocId);
           if (isDuplicate) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('क्षमा करें, यह मोबाइल नंबर पहले से किसी और द्वारा उपयोग में है।'), backgroundColor: Colors.red),
                );
              }
              setState(() => _isSaving = false);
              return;
           }
        }

        String? finalImageUrl = _existingProfileImageUrl;

        // Upload Profile Picture if changed
        if (_newProfileImage != null) {
          try {
            final user2 = FirebaseAuth.instance.currentUser;
            // Force-refresh the auth token to prevent 403 from Firebase Storage
            await user2?.getIdToken(true);
            final uid = user2?.uid ?? 'anon_${DateTime.now().millisecondsSinceEpoch}';
            final uploadedUrl = await StorageService.uploadProfilePhoto(
              file: _newProfileImage!,
              storagePath: 'writer_profiles/$uid.jpg',
            );
            if (uploadedUrl != null) finalImageUrl = uploadedUrl;
          } catch (uploadError) {
            debugPrint('Image Upload Error on Edit: $uploadError');
          }
        }

        // Prepare Update Data
        final updateData = {
          'fullName': _fullNameController.text.trim(),
          'penName': _penNameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'gender': _selectedGender,
          'bio': _bioController.text.trim(),
          'preferredGenres': _selectedGenres,
          'previousPublications': _publicationsController.text.trim(),
          'profileImageUrl': finalImageUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update writer_registrations collection
        await FirebaseFirestore.instance
            .collection('writer_registrations')
            .doc(_registrationDocId)
            .update(updateData);

        // Update users collection
        if (user != null) {
          final newWriterName = _penNameController.text.trim().isNotEmpty ? _penNameController.text.trim() : _fullNameController.text.trim();
          
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
            'writerName': newWriterName,
            'photoURL': finalImageUrl, // Update the root photo as well if changed
          });
          
          // Update FirebaseAuth display name and photo
          await user.updateDisplayName(newWriterName);
          if (_newProfileImage != null) {
            await user.updatePhotoURL(finalImageUrl);
          }
          // Reload the cached FirebaseAuth user so callers see updated data
          await user.reload();

          // Batch-update all writer_articles by this author so denormalized
          // authorName / authorImageUrl stay in sync with the profile.
          try {
            final articlesSnapshot = await FirebaseFirestore.instance
                .collection('writer_articles')
                .where('authorId', isEqualTo: user.uid)
                .get();

            final batch = FirebaseFirestore.instance.batch();
            for (final articleDoc in articlesSnapshot.docs) {
              batch.update(articleDoc.reference, {
                'authorName': newWriterName,
                'authorImageUrl': ?finalImageUrl,
              });
            }
            await batch.commit();
          } catch (articleUpdateError) {
            debugPrint('Non-critical: failed to update articles author info: $articleUpdateError');
          }
        }
        
        // Delete old image from Storage if successfully replaced
        if (_newProfileImage != null && finalImageUrl != _existingProfileImageUrl && _existingProfileImageUrl != null && _existingProfileImageUrl!.isNotEmpty) {
           await _deleteOldProfileImage(_existingProfileImageUrl!);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Return true so caller can refresh

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('अपडेट विफल: $e'), backgroundColor: Colors.red),
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

    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        appBar: AppBar(
          flexibleSpace: Container(decoration: const BoxDecoration(gradient: AppColors.appbarGradient)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
      );
    }

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        ),
        title: Text(
          'प्रोफ़ाइल संपादित करें',
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
                  'अपना लेखक विवरण अपडेट करें',
                  style: GoogleFonts.notoSansDevanagari(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.5,
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
                            image: _newProfileImage != null
                                ? DecorationImage(
                                    image: FileImage(_newProfileImage!),
                                    fit: BoxFit.cover,
                                  )
                                : (_existingProfileImageUrl != null && _existingProfileImageUrl!.isNotEmpty)
                                    ? DecorationImage(
                                        image: NetworkImage(_existingProfileImageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                          ),
                          child: (_newProfileImage == null && _existingProfileImageUrl == null)
                              ? Icon(Icons.person_outline, size: 36, color: hintColor)
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
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
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

                // Email usually matches Auth email so it shouldn't really be edited here, but we'll show it readonly
                _buildTextField(
                  controller: _emailController,
                  label: 'ईमेल पता (Email)',
                  icon: Icons.email_outlined,
                  isDark: isDark,
                  readOnly: true, // Tied to Firebase Auth
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'लिंग (Gender) - वैकल्पिक',
                      labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
                      prefixIcon: Icon(Icons.wc_outlined, color: AppColors.primaryRed.withOpacity(0.7), size: 20),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.black12)),
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
                          readOnly: _phoneVerified && _phoneController.text.trim() != _originalPhone && _phoneController.text.trim() != '',
                          style: TextStyle(color: DesignTokens.textPrimaryOn(isDark)),
                          validator: (value) {
                            if (value != null && value.isNotEmpty && value.length < 10) return 'वैध नंबर दर्ज करें';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: 'फ़ोन नंबर (Phone) - वैकल्पिक',
                            labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
                            prefixText: '+91 ',
                            prefixIcon: Icon(Icons.phone_outlined, color: AppColors.primaryRed.withOpacity(0.7), size: 20),
                            counterText: '',
                            filled: true,
                            fillColor: (_phoneVerified && _phoneController.text.trim() != _originalPhone) ? Colors.grey.shade100 : Colors.white,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black12)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.black12)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryRed, width: 1.5)),
                            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
                          ),
                        ),
                      ),
                      if (!_phoneVerified || _isVerifying) ...[
                        const SizedBox(width: 12),
                        Container(
                          height: 56, // Match text field height roughly
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.primaryRed.withOpacity(0.3)),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _isVerifying ? null : _sendOtp,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Center(
                                  child: _isVerifying 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryRed))
                                    : const Text('सत्यापित\nकरें', textAlign: TextAlign.center, style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                _buildSectionTitle('लेखन प्रोफ़ाइल', isDark),

                _buildTextField(
                  controller: _bioController,
                  label: 'परिचय (Bio)',
                  icon: Icons.description_outlined,
                  hint: 'अपनी लेखन यात्रा का एक छोटा सारांश...',
                  maxLines: 4,
                  isDark: isDark,
                  validator: (value) => value == null || value.isEmpty ? 'कृपया अपना परिचय दें' : null,
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
                  hint: '12 अंकों का आधार नंबर',
                  isDark: isDark,
                  readOnly: true, // Aadhar should not be modified later as per user request
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    '* आधार नंबर को बाद में बदला नहीं जा सकता है।',
                    style: TextStyle(color: Colors.red.shade400, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Submit Button ──
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryLight,
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
                            'अपडेट सहेजें',
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
    bool readOnly = false,
  }) {
    final bgColor = readOnly ? Colors.grey.shade100 : Colors.white;
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
        readOnly: readOnly,
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

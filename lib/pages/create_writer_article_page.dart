import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/writer_article_service.dart';
import '../models/writer_article.dart';

class CreateWriterArticlePage extends StatefulWidget {
  const CreateWriterArticlePage({super.key});

  @override
  State<CreateWriterArticlePage> createState() => _CreateWriterArticlePageState();
}

class _CreateWriterArticlePageState extends State<CreateWriterArticlePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _scrollController = ScrollController();

  late QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();

  final List<String> _categories = ['लेख', 'कहानी', 'कविता', 'ग़ज़ल', 'संस्मरण'];
  String _selectedCategory = 'लेख';

  File? _coverImage;
  final ImagePicker _picker = ImagePicker();

  bool _isPublishing = false;
  bool _hasUnsavedChanges = false;
  final WriterArticleService _articleService = WriterArticleService();

  // Stats
  int _wordCount = 0;
  int _charCount = 0;
  int _readTimeMin = 1;

  @override
  void initState() {
    super.initState();
    _quillController = QuillController.basic();
    _quillController.addListener(_onContentChanged);
    _titleController.addListener(() {
      if (!_hasUnsavedChanges && _titleController.text.isNotEmpty) {
        setState(() => _hasUnsavedChanges = true);
      }
    });
  }

  void _onContentChanged() {
    final text = _quillController.document.toPlainText().trim();
    final words = text.isEmpty ? 0 : text.split(RegExp(r'\s+')).length;
    final chars = text.length;
    final readTime = (words / 200).ceil().clamp(1, 999);

    setState(() {
      _wordCount = words;
      _charCount = chars;
      _readTimeMin = readTime;
      _hasUnsavedChanges = true;
    });
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
        setState(() {
          _coverImage = file;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<bool> _onWillPop() async {
    if (!_hasUnsavedChanges) return true;

    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.accentOrange, size: 48),
        title: const Text('रचना छोड़ें?', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'आपने जो लिखा है वह सेव नहीं होगा। क्या आप वाकई बाहर जाना चाहते हैं?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('लिखते रहें', style: TextStyle(color: AppColors.primaryRed, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('छोड़ दें', style: TextStyle(color: Colors.grey.shade600)),
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _quillController.dispose();
    _titleFocusNode.dispose();
    _editorFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _publishArticle() async {
    final plainText = _quillController.document.toPlainText().trim();

    if (!_formKey.currentState!.validate()) return;
    if (plainText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया सामग्री दर्ज करें'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isPublishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception("User not logged in");

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final String authorName = userData['writerName'] ?? userData['displayName'] ?? 'Unknown Author';

      final writerRegDoc = await FirebaseFirestore.instance
          .collection('writer_registrations')
          .where('uid', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      String? authorImageUrl = userData['photoURL'];
      if (writerRegDoc.docs.isNotEmpty) {
        final regData = writerRegDoc.docs.first.data();
        if (regData['profileImageUrl'] != null && regData['profileImageUrl'].toString().isNotEmpty) {
          authorImageUrl = regData['profileImageUrl'];
        }
      }

      String? coverImageUrl;
      if (_coverImage != null) {
        // Force-refresh the auth token before uploading — stale tokens return 403.
        await currentUser.getIdToken(true);
        coverImageUrl = await _articleService.uploadCoverImage(_coverImage!);
        if (coverImageUrl == null) {
          if (mounted) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('कवर फ़ोटो अपलोड नहीं हो सकी। कृपया पुनः प्रयास करें।'),
                backgroundColor: Colors.red,
              ),
            );
          }
          setState(() => _isPublishing = false);
          return;
        }
      }

      final bool isAdmin = userData['isAdmin'] == true || currentUser.email == 'vivechanaoaj@gmail.com';

      // Store the Delta JSON for rich formatting
      final deltaJson = jsonEncode(_quillController.document.toDelta().toJson());

      // strict access boundaries enforcement
      final article = WriterArticle(
        id: '',
        title: _titleController.text.trim(),
        content: deltaJson,
        category: _selectedCategory,
        authorId: currentUser.uid,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        coverImageUrl: coverImageUrl,
        createdAt: DateTime.now(),
        status: isAdmin ? 'approved' : 'pending',
      );

      final result = await _articleService.submitArticle(article);

      if (!mounted) return;

      if (result != null) {
        _hasUnsavedChanges = false;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('आपकी रचना समीक्षा के लिए सफलतापूर्वक सबमिट कर दी गई है!'),
            backgroundColor: Colors.green,
          ),
        );
        navigator.pop(true);
      } else {
        throw Exception("Failed to publish");
      }
    } catch (e) {
      if (mounted) setState(() => _isPublishing = false);
      messenger.showSnackBar(
        SnackBar(content: Text('प्रकाशन में त्रुटि: $e'), backgroundColor: Colors.red),
      );
      return;
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 50;

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: DesignTokens.scaffoldOn(isDark),
        body: Column(
          children: [
            // ── AppBar ──
            _buildAppBar(),

            // ── Main Content ──
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cover Image
                      _buildCoverImageSection(isDark),
                      const SizedBox(height: 24),

                      // Category Chips
                      _buildCategoryChips(isDark),
                      const SizedBox(height: 24),

                      // Title
                      _buildTitleField(isDark),
                      const SizedBox(height: 8),

                      // Stats bar
                      _buildStatsBar(isDark),
                      const SizedBox(height: 16),

                      // Divider
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryRed.withOpacity(isDark ? 0.8 : 0.6), AppColors.accentOrange.withOpacity(isDark ? 0.6 : 0.3), Colors.transparent],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Rich Text Editor
                      _buildRichEditor(isDark),
                    ],
                  ),
                ),
              ),
            ),

            // ── Formatting Toolbar (above keyboard) ──
            if (isKeyboardOpen) _buildQuillToolbar(isDark),
          ],
        ),
      ),
    );
  }

  // ───────────── AppBar ─────────────
  Widget _buildAppBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: AppColors.appbarGradient,
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () async {
                final shouldPop = await _onWillPop();
                if (shouldPop && mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(width: 4),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'नई रचना',
                  style: GoogleFonts.notoSansDevanagari(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                if (_hasUnsavedChanges)
                  Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.accentOrange, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      const Text('बिना सेव', style: TextStyle(color: Colors.white60, fontSize: 10)),
                    ],
                  ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _isPublishing
                  ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _publishArticle,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 16, color: AppColors.primaryRed),
                              const SizedBox(width: 6),
                              Text(
                                'प्रकाशित करें',
                                style: TextStyle(
                                  color: AppColors.primaryRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────── Cover Image ─────────────
  Widget _buildCoverImageSection(bool isDark) {
    return GestureDetector(
      onTap: _pickImage,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: _coverImage != null ? 220 : 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: _coverImage == null
              ? LinearGradient(
                  colors: [
                    AppColors.primaryLight.withOpacity(0.05),
                    AppColors.accentOrange.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          border: Border.all(
            color: _coverImage == null 
                ? (isDark ? Colors.white24 : AppColors.primaryLight.withOpacity(0.2)) 
                : Colors.transparent,
            width: 1.5,
          ),
          image: _coverImage != null
              ? DecorationImage(image: FileImage(_coverImage!), fit: BoxFit.cover)
              : null,
          boxShadow: _coverImage != null
              ? [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 16, offset: const Offset(0, 6))]
              : null,
        ),
        child: _coverImage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.08) : AppColors.primaryLight.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add_photo_alternate_outlined, size: 32, color: isDark ? Colors.white60 : AppColors.primaryLight.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'कवर फ़ोटो जोड़ें',
                    style: TextStyle(color: isDark ? Colors.white60 : AppColors.primaryLight.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text('वैकल्पिक • टैप करें', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 11)),
                ],
              )
            : Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.4)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10, right: 10,
                    child: Row(
                      children: [
                        _buildImageActionButton(Icons.edit_rounded, _pickImage),
                        const SizedBox(width: 8),
                        _buildImageActionButton(Icons.close_rounded, () => setState(() => _coverImage = null)),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 14, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.image_rounded, color: Colors.white70, size: 14),
                          SizedBox(width: 4),
                          Text('कवर फ़ोटो', style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildImageActionButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  // ───────────── Category Chips ─────────────
  Widget _buildCategoryChips(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('विधा चुनें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.grey.shade500, letterSpacing: 0.5)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = cat == _selectedCategory;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: isSelected ? (isDark ? null : AppColors.appbarGradient) : null,
                      color: isSelected 
                          ? (isDark ? AppColors.primaryRed : null) 
                          : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected 
                          ? null 
                          : Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppColors.primaryRed.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                          : null,
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected 
                            ? Colors.white 
                            : (isDark ? Colors.white70 : Colors.grey.shade700),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ───────────── Title Field ─────────────
  Widget _buildTitleField(bool isDark) {
    return TextFormField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      style: GoogleFonts.notoSansDevanagari(
        fontSize: 26,
        fontWeight: FontWeight.w800,
        color: DesignTokens.textPrimaryOn(isDark),
        height: 1.3,
      ),
      decoration: InputDecoration(
        hintText: 'शीर्षक लिखें...',
        hintStyle: GoogleFonts.notoSansDevanagari(fontSize: 26, color: isDark ? Colors.white38 : Colors.grey.shade400, fontWeight: FontWeight.w800),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      validator: (value) => value == null || value.trim().isEmpty ? 'शीर्षक आवश्यक है' : null,
      maxLines: null,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => _editorFocusNode.requestFocus(),
    );
  }

  // ───────────── Stats Bar ─────────────
  Widget _buildStatsBar(bool isDark) {
    return Row(
      children: [
        _buildStatChip(Icons.text_fields_rounded, '$_wordCount शब्द', isDark),
        const SizedBox(width: 12),
        _buildStatChip(Icons.abc_rounded, '$_charCount अक्षर', isDark),
        const SizedBox(width: 12),
        _buildStatChip(Icons.schedule_rounded, '$_readTimeMin मिनट पठन', isDark),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : AppColors.primaryLight.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white60 : AppColors.primaryLight.withOpacity(0.5)),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : AppColors.primaryLight.withOpacity(0.6), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ───────────── Rich Text Editor (Quill) ─────────────
  Widget _buildRichEditor(bool isDark) {
    return QuillEditor(
      controller: _quillController,
      focusNode: _editorFocusNode,
      scrollController: ScrollController(),
      config: QuillEditorConfig(
        placeholder: 'अपनी रचना यहाँ लिखें...',
        padding: EdgeInsets.zero,
        autoFocus: false,
        expands: false,
        scrollable: false,
        customStyles: DefaultStyles(
          paragraph: DefaultTextBlockStyle(
            GoogleFonts.notoSansDevanagari(
              fontSize: 17,
              color: DesignTokens.textPrimaryOn(isDark).withOpacity(0.9),
              height: 1.8,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(6, 6),
            const VerticalSpacing(0, 0),
            null,
          ),
          h1: DefaultTextBlockStyle(
            GoogleFonts.notoSansDevanagari(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.primaryDark,
              height: 1.4,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(16, 8),
            const VerticalSpacing(0, 0),
            null,
          ),
          h2: DefaultTextBlockStyle(
            GoogleFonts.notoSansDevanagari(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.primaryDark,
              height: 1.4,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(12, 6),
            const VerticalSpacing(0, 0),
            null,
          ),
          h3: DefaultTextBlockStyle(
            GoogleFonts.notoSansDevanagari(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryDark,
              height: 1.4,
            ),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(8, 4),
            const VerticalSpacing(0, 0),
            null,
          ),
          bold: const TextStyle(fontWeight: FontWeight.w900),
          italic: const TextStyle(fontStyle: FontStyle.italic),
          underline: const TextStyle(decoration: TextDecoration.underline),
          placeHolder: DefaultTextBlockStyle(
            GoogleFonts.notoSansDevanagari(fontSize: 17, color: isDark ? Colors.white38 : Colors.grey.shade400, height: 1.8),
            const HorizontalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            const VerticalSpacing(0, 0),
            null,
          ),
        ),
      ),
    );
  }

  // ───────────── Quill Toolbar ─────────────
  Widget _buildQuillToolbar(bool isDark) {
    return FadeInUp(
      duration: const Duration(milliseconds: 200),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: QuillSimpleToolbar(
            controller: _quillController,
            config: const QuillSimpleToolbarConfig(
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: true,
              showIndent: false,
              showLink: false,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showFontFamily: false,
              showFontSize: false,
              showAlignmentButtons: true,
              showDividers: true,
              multiRowsDisplay: false,
            ),
          ),
        ),
      ),
    );
  }
}

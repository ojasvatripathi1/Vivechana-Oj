import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../constants/app_colors.dart';
import '../models/magazine_edition.dart';
import '../services/magazine_service.dart';

class AdminEditMagazinePage extends StatefulWidget {
  final MagazineEdition edition;
  const AdminEditMagazinePage({super.key, required this.edition});

  @override
  State<AdminEditMagazinePage> createState() => _AdminEditMagazinePageState();
}

class _AdminEditMagazinePageState extends State<AdminEditMagazinePage> {
  final _formKey = GlobalKey<FormState>();
  final _magazineService = MagazineService();
  
  File? _newCoverImage;
  File? _newPdfFile;
  
  late TextEditingController _subtitleController;
  late TextEditingController _highlightsController;
  late TextEditingController _pageCountController;
  
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _subtitleController = TextEditingController(text: widget.edition.subtitle);
    _highlightsController = TextEditingController(text: widget.edition.highlights.join(', '));
    _pageCountController = TextEditingController(text: widget.edition.pageCount.toString());
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 70,
      maxWidth: 1080,
      maxHeight: 1080,
    );
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      setState(() => _newCoverImage = file);
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() => _newPdfFile = file);
      
      try {
        final bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final int count = document.pages.count;
        document.dispose();
        setState(() => _pageCountController.text = count.toString());
      } catch (e) {
        debugPrint('Error reading PDF pages: $e');
      }
    }
  }

  Future<void> _update() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isUpdating = true);

    try {
      final highlightsList = _highlightsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final updatedEdition = MagazineEdition(
        id: widget.edition.id,
        title: widget.edition.title, // ID/Title/Month/Year typically stay same for update
        subtitle: _subtitleController.text.trim(),
        coverUrl: widget.edition.coverUrl,
        pdfUrl: widget.edition.pdfUrl,
        month: widget.edition.month,
        year: widget.edition.year,
        isLatest: widget.edition.isLatest,
        isUploaded: true,
        pageCount: int.tryParse(_pageCountController.text.trim()) ?? widget.edition.pageCount,
        highlights: highlightsList,
      );

      final success = await _magazineService.updateMagazine(
        updatedEdition,
        newCover: _newCoverImage,
        newPdf: _newPdfFile,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('मैगज़ीन सफलतापूर्वक अपडेट हुई! (Updated successfully)'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception('Update failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  void dispose() {
    _subtitleController.dispose();
    _highlightsController.dispose();
    _pageCountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.edition.title} सुधारें (Edit)'),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
      ),
      body: _isUpdating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryRed),
                  SizedBox(height: 16),
                  Text('अपडेट किया जा रहा है... (Updating...)', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cover Image Section
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Current Cover
                        Column(
                          children: [
                            const Text('वर्तमान कवर', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(widget.edition.coverUrl, width: 100, height: 140, fit: BoxFit.cover),
                            ),
                          ],
                        ),
                        const SizedBox(width: 20),
                        const Icon(Icons.arrow_forward, color: Colors.grey),
                        const SizedBox(width: 20),
                        // New Cover Picker
                        GestureDetector(
                          onTap: _pickImage,
                          child: Column(
                            children: [
                              const Text('नया कवर (बदलें)', style: TextStyle(fontSize: 12, color: AppColors.primaryRed)),
                              const SizedBox(height: 4),
                              Container(
                                height: 140,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: _newCoverImage != null ? AppColors.primaryRed : (isDark ? Colors.grey.shade700 : Colors.grey.shade300)),
                                ),
                                child: _newCoverImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(_newCoverImage!, fit: BoxFit.cover),
                                      )
                                    : const Center(child: Icon(Icons.add_a_photo, color: Colors.grey)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // PDF File Picker
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: _newPdfFile != null ? AppColors.primaryRed : Colors.grey.shade400),
                      ),
                      leading: const Icon(Icons.picture_as_pdf, color: AppColors.primaryRed),
                      title: Text(_newPdfFile != null 
                          ? 'नया: ${_newPdfFile!.path.split('/').last.split('\\').last}' 
                          : 'पीडीएफ बदलें (Replace PDF)'),
                      subtitle: _newPdfFile == null ? const Text('वर्तमान पीडीएफ सुरक्षित है', style: TextStyle(fontSize: 11)) : null,
                      trailing: ElevatedButton(
                        onPressed: _pickPdf,
                        child: const Text('ब्राउज़'),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title (Read only to avoid ID issues)
                    TextFormField(
                      initialValue: widget.edition.title,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'महीना और वर्ष (Month & Year) [ID cannot be changed]', border: OutlineInputBorder(), filled: true),
                    ),
                    const SizedBox(height: 16),

                    // Metadata Texts
                    TextFormField(
                      controller: _subtitleController,
                      decoration: const InputDecoration(labelText: 'उपशीर्षक / टैगलाइन (Subtitle)', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _highlightsController,
                      decoration: const InputDecoration(
                        labelText: 'मुख्य लेख (Highlights)',
                        hintText: 'अल्पविराम (comma) से अलग करें',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    TextFormField(
                      controller: _pageCountController,
                      decoration: const InputDecoration(labelText: 'पृष्ठ संख्या (Page Count)', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                      validator: (v) => v!.isEmpty ? 'अनिवार्य' : null,
                    ),
                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
                        onPressed: _update,
                        child: const Text('अपडेट सुरक्षित करें (Save Changes)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

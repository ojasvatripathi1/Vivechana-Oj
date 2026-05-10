import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../constants/app_colors.dart';
import '../models/magazine_edition.dart';
import '../services/magazine_service.dart';
import '../services/storage_service.dart';

class AdminPublishMagazineTab extends StatefulWidget {
  const AdminPublishMagazineTab({super.key});

  @override
  State<AdminPublishMagazineTab> createState() => _AdminPublishMagazineTabState();
}

class _AdminPublishMagazineTabState extends State<AdminPublishMagazineTab> {
  final _formKey = GlobalKey<FormState>();
  final _magazineService = MagazineService();
  
  File? _coverImage;
  File? _pdfFile;
  
  String _selectedMonth = 'जनवरी';
  String? _combinedMonth; // Optional secondary month
  int _selectedYear = DateTime.now().year;
  
  final _subtitleController = TextEditingController();
  final _highlightsController = TextEditingController(); // comma-separated
  final _pageCountController = TextEditingController(text: '48');
  
  bool _isPublishing = false;

  final List<String> _hindiMonths = [
    'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
    'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
  ];

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
      setState(() {
        _coverImage = file;
      });
    }
  }

  Future<void> _pickPdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      setState(() {
        _pdfFile = file;
      });
      
      // Auto-fetch page count
      try {
        final bytes = await file.readAsBytes();
        final PdfDocument document = PdfDocument(inputBytes: bytes);
        final int count = document.pages.count;
        document.dispose();
        
        setState(() {
          _pageCountController.text = count.toString();
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF पढ़ा गया: $count पृष्ठ (PDF parsed: $count pages)'),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error reading PDF pages: $e');
      }
    }
  }

  String _generateEditionId() {
    final monthIndex = _hindiMonths.indexOf(_selectedMonth) + 1;
    final monthStr = monthIndex.toString().padLeft(2, '0');
    return '$_selectedYear-$monthStr';
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    if (_coverImage == null || _pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कवर इमेज और पीडीएफ दोनों आवश्यक हैं। (Cover and PDF are required)')),
      );
      return;
    }

    setState(() => _isPublishing = true);

    try {
      // 1. Upload Cover Image
      final coverUrl = await _magazineService.uploadMagazineFile(_coverImage!, isPdf: false);
      if (coverUrl == null) throw Exception('Cover image upload failed');

      // 2. Upload PDF File
      final pdfUrl = await _magazineService.uploadMagazineFile(_pdfFile!, isPdf: true);
      if (pdfUrl == null) throw Exception('PDF file upload failed');

      // 3. Create Edition Object
      final id = _generateEditionId();
      
      // Determine UI Display Titles
      final String monthDisplay = _combinedMonth != null && _combinedMonth!.isNotEmpty
          ? '$_combinedMonth-$_selectedMonth'
          : _selectedMonth;
      final String title = '$monthDisplay $_selectedYear';
      
      final highlightsList = _highlightsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final edition = MagazineEdition(
        id: id,
        title: title,
        subtitle: _subtitleController.text.trim(),
        coverUrl: coverUrl,
        pdfUrl: pdfUrl,
        month: monthDisplay,
        year: _selectedYear,
        isLatest: true, // we assume newly published is latest
        isUploaded: true,
        pageCount: int.tryParse(_pageCountController.text.trim()) ?? 48,
        highlights: highlightsList,
      );

      // 4. Save to Firestore
      final success = await _magazineService.publishMagazine(edition);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('मैगज़ीन सफलतापूर्वक प्रकाशित हुई! (Magazine published successfully)'), backgroundColor: Colors.green),
          );
          // reset form
          setState(() {
            _coverImage = null;
            _pdfFile = null;
            _subtitleController.clear();
            _highlightsController.clear();
            _pageCountController.text = '48';
          });
        }
      } else {
        throw Exception('Failed to save to Firestore');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
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
    return _isPublishing
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: AppColors.primaryRed),
                SizedBox(height: 16),
                Text('प्रकाशित किया जा रहा है... (Publishing...)', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  // Cover Image Picker
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      height: 200,
                      width: 140,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isDark ? Colors.grey.shade700 : Colors.grey.shade400),
                      ),
                      child: _coverImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(_coverImage!, fit: BoxFit.cover),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                SizedBox(height: 8),
                                Text('कवर पेज', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Month and Year Selection
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _selectedMonth,
                          decoration: const InputDecoration(labelText: 'महीना (Month)', border: OutlineInputBorder()),
                          items: _hindiMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedMonth = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedYear,
                          decoration: const InputDecoration(labelText: 'वर्ष (Year)', border: OutlineInputBorder()),
                          items: List.generate(10, (i) => DateTime.now().year - 2 + i)
                              .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedYear = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Optional Combined Month
                  DropdownButtonFormField<String?>(
                    initialValue: _combinedMonth,
                    decoration: const InputDecoration(
                      labelText: 'अतिरिक्त महीना (Combined Month) [वैकल्पिक]',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('कोई नहीं (None)'),
                      ),
                      ..._hindiMonths.map((m) => DropdownMenuItem(value: m, child: Text(m))),
                    ],
                    onChanged: (val) {
                      setState(() => _combinedMonth = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // PDF File Picker
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey.shade400),
                    ),
                    leading: const Icon(Icons.picture_as_pdf, color: AppColors.primaryRed),
                    title: Text(_pdfFile != null ? _pdfFile!.path.split('/').last.split('\\').last : 'पीडीएफ चुनें (Select PDF)'),
                    trailing: ElevatedButton(
                      onPressed: _pickPdf,
                      child: const Text('ब्राउज़'),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Texts
                  TextFormField(
                    controller: _subtitleController,
                    decoration: const InputDecoration(labelText: 'उपशीर्षक / टैगलाइन (Subtitle) [वैकल्पिक/Optional]', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _highlightsController,
                    decoration: const InputDecoration(
                      labelText: 'मुख्य लेख (Highlights) [वैकल्पिक/Optional]',
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

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryRed, foregroundColor: Colors.white),
                      onPressed: _publish,
                      child: const Text('मैगज़ीन प्रकाशित करें', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
  }
}

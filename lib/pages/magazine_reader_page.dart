import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../constants/app_colors.dart';
import '../models/magazine_edition.dart';

class MagazineReaderPage extends StatefulWidget {
  final MagazineEdition edition;

  const MagazineReaderPage({super.key, required this.edition});

  @override
  State<MagazineReaderPage> createState() => _MagazineReaderPageState();
}

class _MagazineReaderPageState extends State<MagazineReaderPage> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfController = PdfViewerController();
  bool _showToolbar = true;
  int _currentPage = 1;
  int _totalPages = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint('Loading PDF from: ${widget.edition.pdfUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showToolbar
          ? AppBar(
              backgroundColor: AppColors.primaryDark,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.edition.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'विवेचना-ओज मैगज़ीन',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              actions: [
                // Page indicator
                if (_totalPages > 0)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_currentPage / $_totalPages',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                  onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel + 0.25).clamp(0.75, 3.0),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                  onPressed: () => _pdfController.zoomLevel = (_pdfController.zoomLevel - 0.25).clamp(0.75, 3.0),
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showToolbar = !_showToolbar),
        child: _errorMessage != null
            ? Container(
                color: Colors.black,
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_rounded, color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          const Text(
                            'PDF लोड नहीं हो सकी',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              border: Border.all(color: Colors.amber, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⚠️ PDF लोड नहीं हो सकी।\n\nकृपया जाँचें:\n1. इंटरनेट कनेक्शन सक्रिय है\n2. PDF का लिंक सही है\n3. ऐप को पुनः प्रारंभ करें',
                              style: TextStyle(color: Colors.amber, fontSize: 11),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('वापस जाएँ'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : SfPdfViewer.network(
              widget.edition.pdfUrl,
              key: _pdfViewerKey,
              controller: _pdfController,
              onDocumentLoaded: (details) {
                setState(() => _totalPages = details.document.pages.count);
              },
              onDocumentLoadFailed: (details) {
                debugPrint('PDF Load Failed: ${details.error}');
                setState(() => _errorMessage = 'Failed to load PDF');
              },
              onPageChanged: (details) {
                setState(() => _currentPage = details.newPageNumber);
              },
              canShowScrollHead: true,
              canShowScrollStatus: true,
              pageLayoutMode: PdfPageLayoutMode.continuous,
            ),
      ),
      // Bottom navigation
      bottomNavigationBar: _showToolbar
          ? Container(
              color: AppColors.primaryDark,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.first_page_rounded, color: Colors.white),
                      onPressed: () => _pdfController.jumpToPage(1),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_before_rounded, color: Colors.white),
                      onPressed: () {
                        if (_currentPage > 1) {
                          _pdfController.previousPage();
                        }
                      },
                    ),
                    Text(
                      'पृष्ठ $_currentPage${_totalPages > 0 ? ' / $_totalPages' : ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    IconButton(
                      icon: const Icon(Icons.navigate_next_rounded, color: Colors.white),
                      onPressed: () {
                        if (_currentPage < _totalPages) {
                          _pdfController.nextPage();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.last_page_rounded, color: Colors.white),
                      onPressed: () => _pdfController.jumpToPage(_totalPages),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

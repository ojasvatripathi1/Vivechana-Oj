import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../models/article.dart';
import '../services/news_service.dart';
import '../utils/app_routes.dart';
import 'article_detail_page.dart';
import 'package:intl/intl.dart';
import '../config/design_tokens.dart';

// Helper for highlighted text
class HighlightedText extends StatelessWidget {
  final String text;
  final String keyword;
  final TextStyle style;
  final TextStyle highlightStyle;

  const HighlightedText({
    super.key,
    required this.text,
    required this.keyword,
    required this.style,
    required this.highlightStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (keyword.isEmpty) return Text(text, style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    
    List<TextSpan> spans = [];
    int start = 0;
    String lowerText = text.toLowerCase();
    String lowerKeyword = keyword.toLowerCase();

    while (start < text.length) {
      int index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start), style: style));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }
      spans.add(TextSpan(text: text.substring(index, index + keyword.length), style: highlightStyle));
      start = index + keyword.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }
}

class SearchPage extends StatefulWidget {
  final String? preFillQuery;
  const SearchPage({super.key, this.preFillQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final NewsService _newsService = NewsService();
  Timer? _debounce;

  bool _isFocused = false;
  String _query = '';
  bool _isLoading = false;
  bool _showSuggestions = true;
  List<Article> _allResults = [];
  List<Article> _filteredResults = [];

  final List<String> _recentSearches = [];
  List<String> _trendingKeywords = ['लोड हो रहा है...'];

  // Filters State
  final List<String> _categories = ['राजनीति', 'खेल', 'टेक्नोलॉजी', 'अर्थव्यवस्था', 'विश्व', 'मनोरंजन'];
  String? _selectedCategory;
  
  final List<String> _dateOptions = ['आज', 'इस सप्ताह', 'इस महीने', 'सभी'];
  String _selectedDate = 'सभी';
  
  final List<String> _sourceOptions = ['BBC News हिंदी', 'आज तक', 'दैनिक भास्कर', 'अमर उजाला', 'News Source'];
  final List<String> _selectedSources = [];
  
  final List<String> _sortOptions = ['नवीनतम', 'लोकप्रिय', 'सबसे अधिक पढ़ी गई'];
  String _selectedSort = 'नवीनतम';

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _isFocused = _searchFocusNode.hasFocus;
        if (_isFocused) _showSuggestions = true;
      });
    });
    _loadTrendingKeywords();

    if (widget.preFillQuery != null && widget.preFillQuery!.isNotEmpty) {
      _searchController.text = widget.preFillQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.preFillQuery!);
      });
    }
  }

  Future<void> _loadTrendingKeywords() async {
    final keywords = await _newsService.fetchTrendingKeywords();
    if (mounted) {
      setState(() {
        _trendingKeywords = keywords;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _query = query;
      _showSuggestions = false;
      _isLoading = true;
    });

    if (!_recentSearches.contains(query) && query.isNotEmpty) {
      _recentSearches.insert(0, query);
      if (_recentSearches.length > 5) _recentSearches.removeLast();
    }

    try {
      final response = await _newsService.fetchNews(query: query);
      final List<Article> rawResults = response['articles'] as List<Article>;
      _allResults = rawResults;
      _applyFilters();
    } catch (e) {
      print('Search Error: $e');
      setState(() {
        _allResults = [];
        _filteredResults = [];
        _isLoading = false;
      });
    }
  }

  DateTime? _parseDate(String dateStr) {
    final formats = [
      DateFormat("EEE, dd MMM yyyy HH:mm:ss 'GMT'"),
      DateFormat("EEE, dd MMM yyyy HH:mm:ss Z"),
      DateFormat("dd MMM yyyy HH:mm:ss Z"),
      DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'"),
      DateFormat("yyyy-MM-dd HH:mm:ss"),
    ];
    for (var format in formats) {
      try { return format.parse(dateStr, true).toLocal(); } catch (_) {}
    }
    return null;
  }

  void _applyFilters() {
    List<Article> temp = List.from(_allResults);

    // Apply category filter
    if (_selectedCategory != null) {
      temp = temp.where((a) => a.category == _selectedCategory || _query.contains(_selectedCategory!)).toList();
    }

    // Apply Source Filter
    if (_selectedSources.isNotEmpty) {
      temp = temp.where((a) => _selectedSources.contains(a.author)).toList();
    }

    // Date filtering using robust parser
    if (_selectedDate != 'सभी') {
      final now = DateTime.now();
      temp = temp.where((a) {
         final pubDate = _parseDate(a.date);
         if (pubDate == null) return true; // Leave as true if completely unparsable
         final diff = now.difference(pubDate);
         if (_selectedDate == 'आज') return diff.inHours <= 24;
         if (_selectedDate == 'इस सप्ताह') return diff.inDays <= 7;
         if (_selectedDate == 'इस महीने') return diff.inDays <= 30;
         return true;
      }).toList();
    }

    // Sort
    if (_selectedSort == 'लोकप्रिय' || _selectedSort == 'सबसे अधिक पढ़ी गई') {
      temp.shuffle();
    }

    setState(() {
      _filteredResults = temp;
      _isLoading = false;
    });
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bool isDark = Theme.of(context).brightness == Brightness.dark;
            final Color bgColor = DesignTokens.scaffoldOn(isDark);
            final Color textColor = DesignTokens.textPrimaryOn(isDark);
            final Color headerColor = isDark ? Colors.white : const Color(0xFF740A03);

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                   Container(
                     margin: const EdgeInsets.only(top: 10),
                     width: 40, height: 4,
                     decoration: BoxDecoration(color: Colors.grey.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
                   ),
                   Padding(
                     padding: const EdgeInsets.all(20),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Text('फ़िल्टर चुनें', style: TextStyle(color: headerColor, fontSize: 18, fontWeight: FontWeight.bold)),
                         IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                       ],
                     ),
                   ),
                   Expanded(
                     child: ListView(
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       children: [
                         Text('श्रेणी', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         const SizedBox(height: 10),
                         Wrap(
                           spacing: 8, runSpacing: 8,
                           children: _categories.map((cat) {
                             bool isSelected = _selectedCategory == cat;
                             return GestureDetector(
                               onTap: () => setSheetState(() {
                                 _selectedCategory = isSelected ? null : cat;
                               }),
                                 child: AnimatedContainer(
                                   duration: const Duration(milliseconds: 200),
                                   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                   decoration: BoxDecoration(
                                     color: isSelected ? const Color(0xFFC3110C) : (isDark ? const Color(0xFF2C2C2C) : Colors.transparent),
                                     border: Border.all(color: isSelected ? Colors.transparent : (isDark ? Colors.white12 : const Color(0xFF740A03))),
                                     borderRadius: BorderRadius.circular(20),
                                   ),
                                   child: Text(cat, style: TextStyle(color: isSelected ? Colors.white : textColor, fontSize: 12)),
                                 ),
                             );
                           }).toList(),
                         ),
                         const SizedBox(height: 24),
                         
                         Text('तिथि', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         ..._dateOptions.map((date) => RadioListTile<String>(
                           title: Text(date, style: TextStyle(color: textColor, fontSize: 14)),
                           value: date,
                           groupValue: _selectedDate,
                           activeColor: const Color(0xFFC3110C),
                           contentPadding: EdgeInsets.zero,
                           onChanged: (val) {
                             if(val != null) setSheetState(() => _selectedDate = val);
                           },
                         )),
                         
                         const SizedBox(height: 12),
                         Text('स्रोत', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         ..._sourceOptions.map((source) => CheckboxListTile(
                           title: Text(source, style: TextStyle(color: textColor, fontSize: 14)),
                           value: _selectedSources.contains(source),
                           activeColor: const Color(0xFFC3110C),
                           contentPadding: EdgeInsets.zero,
                           controlAffinity: ListTileControlAffinity.leading,
                           onChanged: (val) {
                             setSheetState(() {
                               if (val == true) {
                                 _selectedSources.add(source);
                               } else {
                                 _selectedSources.remove(source);
                               }
                             });
                           },
                         )),
                         
                         const SizedBox(height: 12),
                         Text('सॉर्ट विकल्प', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         Wrap(
                           spacing: 8,
                           children: _sortOptions.map((sort) => ChoiceChip(
                             label: Text(sort),
                             selected: _selectedSort == sort,
                             selectedColor: const Color(0xFFC3110C).withOpacity(0.2),
                             checkmarkColor: const Color(0xFFC3110C),
                             labelStyle: TextStyle(color: _selectedSort == sort ? const Color(0xFFC3110C) : textColor),
                             onSelected: (val) {
                               if (val) setSheetState(() => _selectedSort = sort);
                             }
                           )).toList(),
                         ),
                         const SizedBox(height: 48),
                       ],
                     ),
                   ),
                   Padding(
                     padding: const EdgeInsets.all(20),
                     child: ElevatedButton(
                       onPressed: () {
                         Navigator.pop(context);
                         if (_allResults.isNotEmpty || _query.isNotEmpty) _applyFilters();
                         setState((){});
                       },
                       style: ElevatedButton.styleFrom(
                         backgroundColor: const Color(0xFFE6501B),
                         foregroundColor: Colors.white,
                         minimumSize: const Size(double.infinity, 50),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                       ),
                       child: const Text('लागू करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                     ),
                   ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> get _activeFilters {
    List<String> filters = [];
    if (_selectedCategory != null) filters.add(_selectedCategory!);
    if (_selectedDate != 'सभी') filters.add(_selectedDate);
    filters.addAll(_selectedSources);
    return filters;
  }

  void _removeFilter(String filter) {
    setState(() {
      if (_selectedCategory == filter) {
        _selectedCategory = null;
      } else if (_selectedDate == filter) _selectedDate = 'सभी';
      else if (_selectedSources.contains(filter)) _selectedSources.remove(filter);
    });
    if (_allResults.isNotEmpty || _query.isNotEmpty) _applyFilters();
  }

  void _clearAllFilters() {
    setState(() {
      _selectedCategory = null;
      _selectedDate = 'सभी';
      _selectedSources.clear();
      _selectedSort = 'नवीनतम';
    });
    if (_allResults.isNotEmpty || _query.isNotEmpty) _applyFilters();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = DesignTokens.scaffoldOn(isDark);
    final Color textColor = DesignTokens.textPrimaryOn(isDark);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      color: bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 16, right: 16, bottom: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF280905), Color(0xFF740A03)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: _isFocused ? const Color(0xFFC3110C) : (isDark ? Colors.white12 : Colors.transparent), width: 2),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onSubmitted: _performSearch,
                              onChanged: (val) {
                                setState(() {
                                   _query = val;
                                   if (val.isEmpty) _showSuggestions = true;
                                });
                                
                                if (_debounce?.isActive ?? false) _debounce!.cancel();
                                _debounce = Timer(const Duration(milliseconds: 500), () {
                                  if (val.isNotEmpty) {
                                    _performSearch(val);
                                  } else {
                                    setState(() {
                                      _allResults.clear();
                                      _filteredResults.clear();
                                    });
                                  }
                                });
                              },
                              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.w500),
                              textAlignVertical: TextAlignVertical.center,
                              decoration: InputDecoration(
                                hintText: 'समाचार खोजें...',
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontWeight: FontWeight.normal),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.only(bottom: 12),
                              ),
                            ),
                          ),
                          if (_query.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.cancel_rounded, size: 22, color: Colors.grey),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _query = '';
                                  _showSuggestions = true;
                                  _allResults.clear();
                                  _filteredResults.clear();
                                });
                              },
                            )
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                    onPressed: _openFilterSheet,
                  ),
                ],
              ),
            ),
            
            if (_activeFilters.isNotEmpty)
              Container(
                height: 50,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _activeFilters.map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 8.0, top: 10, bottom: 10),
                    child: ZoomIn(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF740A03),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(filter, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeFilter(filter),
                              child: const Icon(Icons.close, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
                ),
              ),

            Expanded(
              child: Stack(
                children: [
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator(color: Color(0xFFC3110C)))
                  else if (!_showSuggestions && _filteredResults.isEmpty)
                    FadeIn(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 80, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text('कोई परिणाम नहीं मिला।', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                            const SizedBox(height: 8),
                            Text('कोशिश करें अलग शब्दों से।', style: TextStyle(color: Colors.grey)),
                            const SizedBox(height: 24),
                            if (_activeFilters.isNotEmpty)
                              ElevatedButton(
                                onPressed: _clearAllFilters,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC3110C),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                ),
                                child: const Text('फ़िल्टर हटाएँ'),
                              ),
                          ],
                        ),
                      ),
                    )
                  else if (!_showSuggestions)
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredResults.length,
                      itemBuilder: (context, index) {
                        return _buildSearchResultCard(_filteredResults[index], index, isDark);
                      },
                    ),

                  if (_showSuggestions && _query.isEmpty)
                    FadeIn(
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.only(top: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              if (_recentSearches.isNotEmpty) ...[
                                Text('हाल की खोजें', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _recentSearches.map((s) => ActionChip(
                                    label: Text(s, style: TextStyle(fontSize: 13, color: textColor)),
                                    avatar: const Icon(Icons.history, size: 16, color: Colors.grey),
                                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                                    side: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                    onPressed: () {
                                      _searchController.text = s;
                                      _performSearch(s);
                                    },
                                  )).toList(),
                                ),
                                const SizedBox(height: 32),
                              ],
                              Row(
                                children: [
                                  const Icon(Icons.trending_up, color: Color(0xFFC3110C), size: 18),
                                  const SizedBox(width: 8),
                                  Text('ट्रेंडिंग कीवर्ड', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _trendingKeywords.map((k) => ActionChip(
                                  label: Text(k, style: const TextStyle(fontSize: 13, color: Color(0xFFC3110C))),
                                  backgroundColor: const Color(0xFFC3110C).withOpacity(0.08),
                                  side: BorderSide.none,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  onPressed: () {
                                    _searchController.text = k;
                                    _performSearch(k);
                                  },
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResultCard(Article article, int index, bool isDark) {
    final String heroTag = 'search_article_${article.id}_$index';
    return FadeInUp(
      child: GestureDetector(
        onTap: () => Navigator.push(context, AppRoutes.slideUp(ArticleDetailPage(article: article, heroTag: heroTag))),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: DesignTokens.cardColorOn(isDark),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)
              )
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    article.image,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 90, height: 90, color: Colors.grey[300],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFE6501B), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        article.category,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    HighlightedText(
                      text: article.title,
                      keyword: _query,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DesignTokens.textPrimaryOn(isDark)),
                      highlightStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black, backgroundColor: Colors.yellow),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(article.date, style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

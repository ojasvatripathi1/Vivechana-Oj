import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:animate_do/animate_do.dart';

import 'package:google_fonts/google_fonts.dart';
import '../config/design_tokens.dart';
import '../models/article.dart';
import '../services/news_service.dart';
import '../utils/app_routes.dart';
import '../constants/app_colors.dart';
import 'article_detail_page.dart';

class LocalNewsPage extends StatefulWidget {
  const LocalNewsPage({super.key});

  @override
  State<LocalNewsPage> createState() => _LocalNewsPageState();
}

class _LocalNewsPageState extends State<LocalNewsPage> {
  Position? _currentPosition;
  String _locationStatus = '';
  String _cityName = '';
  
  bool _hasRequestedLocation = false;
  bool _isLoadingLocation = false;
  bool _isLoadingNews = false;
  List<Article> _localNews = [];

  @override
  void initState() {
    super.initState();
    // Do not auto-fetch location. Wait for user to tap the button.
  }

  Future<void> _fetchLocationAndNews() async {
    setState(() {
      _hasRequestedLocation = true;
      _isLoadingLocation = true;
      _locationStatus = 'आपकी लोकेशन प्राप्त की जा रही है...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'कृपया डिवाइस की लोकेशन सेवा चालू करें';
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          setState(() {
            _locationStatus = 'लोकेशन की अनुमति अस्वीकृत कर दी गई';
            _isLoadingLocation = false;
          });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _locationStatus = 'लोकेशन की अनुमति हमेशा के लिए अस्वीकृत है। सेटिंग्स में जांचें।';
          _isLoadingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium));
      
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _locationStatus = 'शहर खोजा जा रहा है...';
      });

      // Reverse geocode
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];
        // locality gives city name typically, subAdministrativeArea gives district
        String city = placemark.locality ?? placemark.subAdministrativeArea ?? 'Unknown';
        
        if (!mounted) return;
        setState(() {
          _cityName = city;
          _locationStatus = 'आपके शहर "$city" की ताज़ा ख़बरें';
          _isLoadingLocation = false;
          _isLoadingNews = true;
        });
        
        // Fetch personalized local news
        await _fetchNewsForCity(city);
      } else {
         setState(() {
          _locationStatus = 'शहर का नाम प्राप्त नहीं हो सका';
          _isLoadingLocation = false;
        });
      }

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationStatus = 'लोकेशन प्राप्त करने में त्रुटि: $e';
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _fetchNewsForCity(String city) async {
    try {
      final response = await NewsService().fetchNews(query: city);
      final rawResults = response['articles'] as List<Article>?;
      
      if (!mounted) return;
      setState(() {
        _localNews = rawResults ?? [];
        _isLoadingNews = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localNews = [];
        _isLoadingNews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        title: Text(
          'लोकल न्यूज़',
          style: GoogleFonts.notoSansDevanagari(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF740A03),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: !_hasRequestedLocation 
          ? _buildRequestLocationView() 
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildCityHeader(),
                if (_isLoadingLocation || _isLoadingNews)
                  const Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
                  )
                else if (_localNews.isEmpty)
                  FadeIn(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.explore_off,
                              size: 64,
                              color: DesignTokens.textSecondaryOn(isDark).withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _cityName.isNotEmpty ? '$_cityName से कोई ताज़ा खबर नहीं मिली' : _locationStatus, 
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: DesignTokens.textSecondaryOn(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: _localNews.length,
                      itemBuilder: (context, index) {
                        return _buildLocalNewsCard(_localNews[index], index, isDark);
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildRequestLocationView() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: FadeInUp(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_city_rounded, 
                  size: 80, 
                  color: AppColors.primaryRed,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'अपने शहर की खबरें जानें',
                style: GoogleFonts.notoSansDevanagari(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: DesignTokens.textPrimaryOn(isDark),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'आपके आस-पास क्या हो रहा है, यह जानने के लिए हमें आपकी लोकेशन की आवश्यकता है। हम आपकी लोकेशन सुरक्षित रखते हैं।',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DesignTokens.textSecondaryOn(isDark),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: _fetchLocationAndNews,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  elevation: 4,
                  shadowColor: AppColors.primaryRed.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.my_location_rounded, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'लोकेशन प्राप्त करें',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCityHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF740A03),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FadeInDown(
        child: Column(
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white70, size: 40),
            const SizedBox(height: 12),
            if (_cityName.isNotEmpty) ...[
              Text(
                _cityName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              _locationStatus,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalNewsCard(Article article, int index, bool isDark) {
    final String heroTag = 'local_article_${article.id}_$index';
    return FadeInUp(
      delay: Duration(milliseconds: 50 * index),
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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4)
              )
            ],
            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Hero(
                  tag: heroTag,
                  child: Image.network(
                    article.image,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 100, height: 100, color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: Icon(Icons.broken_image, color: isDark ? Colors.grey[600] : Colors.grey),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryRed.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(6)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on, size: 10, color: AppColors.primaryRed),
                          const SizedBox(width: 4),
                          Text(
                            _cityName,
                            style: const TextStyle(color: AppColors.primaryRed, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.textPrimaryOn(isDark),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      article.date,
                      style: TextStyle(
                        color: DesignTokens.textSecondaryOn(isDark),
                        fontSize: 11,
                      ),
                    ),
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

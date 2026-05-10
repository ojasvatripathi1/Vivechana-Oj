import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:video_compress/video_compress.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/reel_service.dart';
import '../services/storage_service.dart';
import '../models/news_reel.dart';
import '../constants/app_colors.dart';

class AdminNewsReelsTab extends StatefulWidget {
  const AdminNewsReelsTab({super.key});

  @override
  State<AdminNewsReelsTab> createState() => _AdminNewsReelsTabState();
}

class _AdminNewsReelsTabState extends State<AdminNewsReelsTab> {
  final ReelService _reelService = ReelService();
  final _youtubeUrlController = TextEditingController();
  final _titleController = TextEditingController();
  
  bool _isUploading = false;
  File? _selectedVideo;

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
        // Clear youtube url if a file is picked
        _youtubeUrlController.clear();
      });
    }
  }

  Future<String?> _uploadVideoToStorage(File videoFile) async {
    try {
      // Force-refresh auth token before upload
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storagePath = 'news_reels/$timestamp.mp4';
      return await StorageService.uploadVideo(
        file: videoFile,
        storagePath: storagePath,
      );
    } catch (e) {
      debugPrint('[AdminReels] Video upload to Firebase Storage failed: $e');
      return null;
    }
  }

  Future<void> _submitReel() async {
    final title = _titleController.text.trim();
    final ytUrl = _youtubeUrlController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया वीडियो का शीर्षक दर्ज करें')));
      return;
    }

    if (ytUrl.isEmpty && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('कृपया YouTube URL दर्ज करें या कोई वीडियो फ़ाइल चुनें')));
      return;
    }

    setState(() => _isUploading = true);

    try {
      if (ytUrl.isNotEmpty) {
        // Upload YouTube Reel
        await _reelService.addReel(title, ytUrl, ReelType.youtube);
      } else if (_selectedVideo != null) {
        // Upload Native Reel
        File videoToUpload = _selectedVideo!;
        try {
          final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
            _selectedVideo!.path,
            quality: VideoQuality.MediumQuality,
            deleteOrigin: false,
          );
          if (mediaInfo != null && mediaInfo.file != null) {
            videoToUpload = mediaInfo.file!;
          }
        } catch (e) {
          debugPrint('Video compression failed: $e');
        }

        final videoUrl = await _uploadVideoToStorage(videoToUpload);
        if (videoUrl == null) {
          throw Exception('Video upload to Firebase Storage failed.');
        }
        await _reelService.addReel(title, videoUrl, ReelType.native);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('न्यूज़ रील सफलतापूर्वक जोड़ दी गई!'), backgroundColor: Colors.green));
        _titleController.clear();
        _youtubeUrlController.clear();
        setState(() => _selectedVideo = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteReel(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('रील हटाएँ'),
        content: const Text('क्या आप वाकई इस रील को हटाना चाहते हैं?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('रद्द करें')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('हटाएँ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _reelService.deleteReel(id);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      children: [
        // ---------- UPLOAD SECTION ----------
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('नई न्यूज़ रील जोड़ें', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'रील का शीर्षक (Title)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              const Text('विकल्प 1: YouTube Shorts URL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _youtubeUrlController,
                onChanged: (val) {
                  if (val.isNotEmpty && _selectedVideo != null) {
                    setState(() => _selectedVideo = null);
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'YouTube Video/Shorts Link',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.ondemand_video, color: Colors.red),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              const Center(child: Text('--- या ---', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              const SizedBox(height: 16),
              const Text('विकल्प 2: अपनी वीडियो फ़ाइल अपलोड करें', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.video_file),
                    label: const Text('वीडियो चुनें'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey, foregroundColor: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  if (_selectedVideo != null)
                    const Expanded(
                      child: Text('✅ वीडियो फ़ाइल चुनी गई', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitReel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('रील पोस्ट करें', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),

        // ---------- LIST SECTION ----------
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('लाइव न्यूज़ रील्स', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
        ),
        StreamBuilder<List<NewsReel>>(
            stream: _reelService.getReelsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: AppColors.primaryRed));
              }
              final reels = snapshot.data ?? [];
              if (reels.isEmpty) {
                return const Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('कोई रील उपलब्ध नहीं है।', style: TextStyle(color: Colors.grey)),
                ));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  final dateStr = DateFormat('d MMM yyyy, h:mm a').format(reel.createdAt);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: reel.type == ReelType.youtube
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                if (reel.thumbnailUrl != null)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(reel.thumbnailUrl!, width: 60, height: 60, fit: BoxFit.cover),
                                  ),
                                const Icon(Icons.play_circle_fill, color: Colors.red, size: 28),
                              ],
                            )
                          : Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.black87, borderRadius: BorderRadius.circular(6)),
                              child: const Icon(Icons.movie_creation, color: Colors.white),
                            ),
                      title: Text(reel.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        'प्रकार: ${reel.type == ReelType.youtube ? 'YouTube' : 'Native MP4'}\nतारीख़: $dateStr',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteReel(reel.id),
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}

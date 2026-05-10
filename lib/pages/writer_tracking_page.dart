import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';

class WriterTrackingPage extends StatelessWidget {
  const WriterTrackingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('लॉग इन नहीं है')));
    }

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(gradient: AppColors.appbarGradient),
        ),
        title: Text(
          'मेरी स्थिति',
          style: GoogleFonts.notoSansDevanagari(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // ── Registration Status Card ──────────────────────────
          _SectionTitle(label: 'लेखक पंजीकरण'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('writer_registrations')
                .where('uid', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingCard();
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return _InfoCard(
                  icon: Icons.person_add_outlined,
                  iconColor: Colors.grey,
                  title: 'कोई आवेदन नहीं',
                  subtitle: 'आपने अभी तक लेखक पंजीकरण नहीं किया है।',
                  statusLabel: null,
                  statusColor: Colors.grey,
                  date: null,
                );
              }
              final data = snap.data!.docs.first.data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'pending';
              final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
              final name = (data['penName'] as String?)?.isNotEmpty == true
                  ? data['penName'] as String
                  : data['fullName'] as String? ?? '';

              Color statusColor;
              IconData statusIcon;
              String statusLabel;
              String subtitle;

              switch (status) {
                case 'approved':
                  statusColor = Colors.green;
                  statusIcon = Icons.verified_rounded;
                  statusLabel = 'स्वीकृत';
                  subtitle = 'बधाई! आपका आवेदन स्वीकृत हो गया है। आप अब रचनाएँ प्रकाशित कर सकते हैं।';
                  break;
                default: // pending
                  statusColor = Colors.orange;
                  statusIcon = Icons.hourglass_top_rounded;
                  statusLabel = 'समीक्षाधीन';
                  subtitle = 'आपका आवेदन एडमिन की समीक्षा में है। कृपया प्रतीक्षा करें।';
              }

              return _InfoCard(
                icon: statusIcon,
                iconColor: statusColor,
                title: name,
                subtitle: subtitle,
                statusLabel: statusLabel,
                statusColor: statusColor,
                date: submittedAt,
              );
            },
          ),

          const SizedBox(height: 28),

          // ── Articles Status List ──────────────────────────────
          _SectionTitle(label: 'मेरी रचनाएँ'),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('writer_articles')
                .where('authorId', isEqualTo: user.uid)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const _LoadingCard();
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 44, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'अभी कोई रचना नहीं है',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'आपकी सबमिट की गई रचनाएँ यहाँ दिखेंगी।',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              // Sort locally by createdAt descending
              final sorted = [...docs];
              sorted.sort((a, b) {
                final aTs = (a.data() as Map)['createdAt'];
                final bTs = (b.data() as Map)['createdAt'];
                if (aTs == null || bTs == null) return 0;
                return (bTs as dynamic).compareTo(aTs);
              });

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: sorted.asMap().entries.map((entry) {
                    final i = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['title'] as String? ?? '';
                    final category = data['category'] as String? ?? '';
                    final status = data['status'] as String? ?? 'pending';
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final coverUrl = data['coverImageUrl'] as String?;

                    Color statusColor;
                    IconData statusIcon;
                    String statusLabel;
                    String statusDesc;

                    switch (status) {
                      case 'approved':
                        statusColor = Colors.green;
                        statusIcon = Icons.check_circle_rounded;
                        statusLabel = 'प्रकाशित';
                        statusDesc = 'आपकी रचना प्रकाशित हो गई है और पाठक इसे पढ़ सकते हैं।';
                        break;
                      case 'rejected':
                        statusColor = Colors.red;
                        statusIcon = Icons.cancel_rounded;
                        statusLabel = 'अस्वीकृत';
                        statusDesc = 'आपकी रचना अस्वीकृत हुई। आप संशोधन कर पुनः सबमिट कर सकते हैं।';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusIcon = Icons.hourglass_top_rounded;
                        statusLabel = 'समीक्षाधीन';
                        statusDesc = 'आपकी रचना एडमिन की समीक्षा में है।';
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover image or icon
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: coverUrl != null
                                    ? Image.network(
                                        coverUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _articleIconBox(),
                                      )
                                    : _articleIconBox(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Title + status chip row
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Colors.black87,
                                              height: 1.3,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _StatusChip(
                                          label: statusLabel,
                                          color: statusColor,
                                          icon: statusIcon,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Category + date
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryRed.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            category,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryRed,
                                            ),
                                          ),
                                        ),
                                        if (createdAt != null) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('d MMM yyyy').format(createdAt),
                                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // Status description
                                    Text(
                                      statusDesc,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: statusColor.withOpacity(0.8),
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (i < sorted.length - 1)
                          Divider(height: 1, indent: 82, color: Colors.grey.shade100),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _articleIconBox() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.article_outlined, color: AppColors.primaryRed, size: 24),
    );
  }
}

// ── Shared Sub-Widgets ──────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? statusLabel;
  final Color statusColor;
  final DateTime? date;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isEmpty ? 'आपका आवेदन' : title,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                    if (statusLabel != null)
                      _StatusChip(label: statusLabel!, color: statusColor, icon: icon),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.5),
                ),
                if (date != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'सबमिट: ${DateFormat('d MMM yyyy').format(date!)}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip({required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

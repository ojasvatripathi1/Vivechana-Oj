import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Sends payment receipt emails using EmailJS (https://emailjs.com).
///
/// ── EmailJS Setup (one-time, 5 minutes) ─────────────────────────────────
/// 1. Sign up free at https://www.emailjs.com/ ✓ (already done)
/// 2. "Email Services" → Add Service → Gmail → connect vivechanaoaj@gmail.com → copy SERVICE ID
/// 3. "Email Templates" → Create Template → paste the template below → copy TEMPLATE ID
///    Template variables used:
///      {{to_name}}, {{to_email}}, {{plan}}, {{amount}},
///      {{payment_id}}, {{edition_title}}, {{valid_from}}, {{valid_until}}, {{receipt_no}}
/// 4. Account → API Keys → copy PUBLIC KEY
/// 5. Paste the three values in the constants below and hot-reload.
/// ─────────────────────────────────────────────────────────────────────────
class PaymentEmailService {
  // ── Fill these in after getting credentials from emailjs.com ──────────
  static const String _serviceId  = 'YOUR_SERVICE_ID';
  static const String _templateId = 'YOUR_TEMPLATE_ID';
  static const String _publicKey  = 'YOUR_PUBLIC_KEY';
  // ─────────────────────────────────────────────────────────────────────

  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  /// Send a payment receipt email via EmailJS.
  static Future<bool> sendReceipt({
    required String toEmail,
    required String toName,
    required String plan,
    required int amountPaise,
    required String paymentId,
    required DateTime validFrom,
    required DateTime validUntil,
    String? editionTitle,
  }) async {
    if (_serviceId == 'YOUR_SERVICE_ID') {
      debugPrint('[PaymentEmailService] EmailJS not configured yet — skipping email.');
      return false;
    }

    final planLabel = plan == 'annual' ? 'वार्षिक सदस्यता' : 'एकल अंक';
    final amount    = '₹${(amountPaise / 100).toStringAsFixed(0)}';
    final receiptNo = 'VJ-${DateTime.now().millisecondsSinceEpoch}';

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_name':       toName,
            'to_email':      toEmail,
            'plan':          planLabel,
            'amount':        amount,
            'payment_id':    paymentId,
            'edition_title': editionTitle ?? 'सभी अंक',
            'valid_from':    _formatDate(validFrom),
            'valid_until':   _formatDate(validUntil),
            'receipt_no':    receiptNo,
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint('[PaymentEmailService] Receipt sent to $toEmail ✓');
        return true;
      } else {
        debugPrint('[PaymentEmailService] EmailJS error ${response.statusCode}: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[PaymentEmailService] Exception: $e');
      return false;
    }
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  /// Get user contact info from Firestore — used to pre-fill Razorpay checkout.
  static Future<Map<String, String>> getUserContact() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return {};
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};
      return {
        'uid':   user.uid,
        'email': user.email ?? '',
        'name':  user.displayName ?? data['displayName'] ?? data['name'] ?? '',
        'phone': (data['phone'] ?? data['mobileNumber'] ?? '').toString(),
      };
    } catch (_) {
      return {};
    }
  }
}

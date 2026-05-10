import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../config/design_tokens.dart';
import '../services/magazine_service.dart';

class DeliveryAddressPage extends StatefulWidget {
  final String? paymentId;
  final String? userName;

  const DeliveryAddressPage({super.key, this.paymentId, this.userName});

  @override
  State<DeliveryAddressPage> createState() => _DeliveryAddressPageState();
}

class _DeliveryAddressPageState extends State<DeliveryAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addr1Ctrl = TextEditingController();
  final _addr2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  bool _isSaving = false;
  bool _saved = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addr1Ctrl.dispose();
    _addr2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSaving = true);
    // BUG-010 FIX: Only include addressLine2 if the user actually filled it in
    final address = <String, String>{
      'name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'addressLine1': _addr1Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincodeCtrl.text.trim(),
      if (widget.paymentId != null) 'annualPaymentId': widget.paymentId!,
    };
    if (_addr2Ctrl.text.trim().isNotEmpty) {
      address['addressLine2'] = _addr2Ctrl.text.trim();
    }
    await MagazineService().saveDeliveryAddress(uid, address);
    if (!mounted) return;
    setState(() { _isSaving = false; _saved = true; });
  }

  @override
  Widget build(BuildContext context) {
    // BUG-013 FIX: Resolve dark mode from system brightness
    final isDark = MediaQuery.of(context).platformBrightness == Brightness.dark;

    return Scaffold(
      backgroundColor: DesignTokens.scaffoldOn(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'डिलीवरी पता',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: _saved ? _buildSuccess(isDark) : _buildForm(isDark),
    );
  }

  Widget _buildSuccess(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'पता सहेज लिया गया!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: DesignTokens.textPrimaryOn(isDark),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'आपकी मुद्रित पत्रिका अगले अंक से आपके पते पर भेजी जाएगी।',
              style: TextStyle(
                fontSize: 14,
                color: DesignTokens.textSecondaryOn(isDark),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('मुखपृष्ठ पर जाएँ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentOrange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded, color: AppColors.accentOrange, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'मुद्रित पत्रिका इस पते पर भेजी जाएगी। पता सही भरें।',
                      style: TextStyle(
                        fontSize: 12,
                        color: DesignTokens.textSecondaryOn(isDark),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildField(isDark, 'पूरा नाम', _nameCtrl, Icons.person_outline_rounded,
                validator: (v) => v!.isEmpty ? 'नाम आवश्यक है' : null),
            _buildField(isDark, 'मोबाइल नंबर', _phoneCtrl, Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.length < 10 ? 'सही नंबर डालें' : null),
            _buildField(isDark, 'पता पंक्ति 1', _addr1Ctrl, Icons.home_outlined,
                validator: (v) => v!.isEmpty ? 'पता आवश्यक है' : null),
            _buildField(isDark, 'पता पंक्ति 2 (वैकल्पिक)', _addr2Ctrl, Icons.location_on_outlined),
            Row(
              children: [
                Expanded(child: _buildField(isDark, 'शहर', _cityCtrl, Icons.location_city_outlined,
                    validator: (v) => v!.isEmpty ? 'शहर आवश्यक है' : null)),
                const SizedBox(width: 12),
                Expanded(child: _buildField(isDark, 'राज्य', _stateCtrl, Icons.map_outlined,
                    validator: (v) => v!.isEmpty ? 'राज्य आवश्यक है' : null)),
              ],
            ),
            _buildField(isDark, 'पिनकोड', _pincodeCtrl, Icons.pin_drop_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => v!.length != 6 ? '6 अंकों का पिनकोड डालें' : null),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('पता सहेजें', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
    bool isDark,
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: TextStyle(color: DesignTokens.textPrimaryOn(isDark), fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: DesignTokens.textSecondaryOn(isDark), fontSize: 13),
          prefixIcon: Icon(icon, color: AppColors.primaryLight, size: 20),
          filled: true,
          fillColor: DesignTokens.cardColorOn(isDark),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DesignTokens.dividerOn(isDark)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: DesignTokens.dividerOn(isDark)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryRed),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}

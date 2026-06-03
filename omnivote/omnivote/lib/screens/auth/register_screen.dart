import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/webauthn_service.dart';
import '../home/home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController        = TextEditingController();
  final _aadharController      = TextEditingController();
  final _voterIdController     = TextEditingController();
  final _captchaInputController = TextEditingController();

  bool _isLoading          = false;
  bool _biometricAvailable = false;
  bool _enrollBiometric    = false;
  bool _biometricEnrolled  = false;
  bool _webAuthnAvailable  = false;
  bool _webAuthnEnrolled   = false;
  final BiometricService _bio = BiometricService();
  late AnimationController _pulseCtrl;
  bool _agreeToTerms = false;

  // ── Captcha ──────────────────────────────────────────────────
  late String _captchaQuestion;
  late String _captchaAnswer;

  @override
  void initState() {
    super.initState();
    _refreshCaptcha();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    if (!kIsWeb) _checkBiometric();
    if (kIsWeb) _checkWebAuthn();
  }

  void _refreshCaptcha() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789';
    final rng = Random();
    final code = List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
    setState(() {
      _captchaQuestion = code;
      _captchaAnswer   = code;
      _captchaInputController.clear();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aadharController.dispose();
    _voterIdController.dispose();
    _captchaInputController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Register ─────────────────────────────────────────────────
  Future<void> _checkWebAuthn() async {
    final ok = await WebAuthnService.isAvailable();
    if (mounted) setState(() => _webAuthnAvailable = ok);
  }

  Future<void> _registerWebAuthn() async {
    try {
      final api = await OmniVoteApi.init();
      final challengeData = await api.auth.webAuthnRegisterChallenge();
      final result = await WebAuthnService.register(
        challenge: challengeData['challenge'] as String,
        userId: challengeData['userId'] as String,
        userName: challengeData['userName'] as String? ?? 'Voter',
        rpId: challengeData['rpId'] as String? ?? 'localhost',
      );
      if (result['success'] == true) {
        await api.auth.webAuthnRegisterVerify(
          credentialId: result['credentialId'] as String,
          publicKey: result['publicKey'] as String? ?? '',
          clientDataJSON: result['clientDataJSON'] as String,
          attestationObject: result['attestationObject'] as String? ?? '',
        );
        setState(() => _webAuthnEnrolled = true);
        _showSnack('Fingerprint registered for web login!', success: true);
      } else {
        _showSnack(result['error'] as String? ?? 'Fingerprint registration failed.');
      }
    } catch (e) {
      _showSnack('WebAuthn error: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }

  Future<void> _checkBiometric() async {
    final supported = await _bio.isDeviceSupported();
    final enrolled = await _bio.canCheckBiometrics();
    if (mounted) setState(() => _biometricAvailable = supported && enrolled);
  }

  Future<void> _scanForEnrollment() async {
    final result = await _bio.authenticate(
      reason: 'Scan your fingerprint to set up biometric login for OmniVote',
    );
    if (!mounted) return;
    if (result.success) {
      setState(() => _biometricEnrolled = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Fingerprint enrolled! Use it to log in.')),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } else {
      setState(() { _enrollBiometric = false; _biometricEnrolled = false; });
      _showSnack(result.errorMessage ?? 'Fingerprint scan failed. Try again.');
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeToTerms) {
      _showSnack('Please agree to the Terms & Conditions to continue.');
      return;
    }

    if (_captchaInputController.text.trim() != _captchaAnswer) {
      _showSnack('Incorrect security code. Please try again.');
      _refreshCaptcha();
      return;
    }

    // Fingerprint is MANDATORY on web too
    if (kIsWeb && _webAuthnAvailable && !_webAuthnEnrolled) {
      _showSnack('Fingerprint verification is required to register.');
      await _registerWebAuthn();
      if (!_webAuthnEnrolled) return;
    }
    // Fingerprint is MANDATORY on Android
    if (!kIsWeb && _biometricAvailable && !_biometricEnrolled) {
      _showSnack('Fingerprint verification is required to register.');
      await _scanForEnrollment();
      if (!_biometricEnrolled) return;
    }

    setState(() => _isLoading = true);
    try {
      final api  = await OmniVoteApi.init();
      final user = await api.auth.register(
        name:          _nameController.text.trim(),
        aadharNumber:  _aadharController.text.replaceAll(' ', ''),
        voterIdNumber: _voterIdController.text.trim().toUpperCase(),
        devicePlatform: 'android',
      );
      // If fingerprint was enrolled during registration, enable it on the server
      var navigateUser = user;
      if (_biometricEnrolled) {
        try {
          await api.auth.enableBiometric('device_key');
          navigateUser = user.copyWith(biometricEnabled: true);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(user: navigateUser)),
            (route) => false,
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
      _refreshCaptcha();
    } catch (e) {
      _showSnack('Error: ${e.toString().replaceAll('Exception: ', '')}');
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
    ));
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.paddingXL,
              vertical: AppDimensions.paddingM,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: AppColors.textPrimary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              const SizedBox(height: AppDimensions.paddingS),

              FadeInDown(child: _buildHeader()),
              const SizedBox(height: AppDimensions.paddingXL),

              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Form(
                  key: _formKey,
                  child: Column(children: [

                    _buildInputField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'As on your Voter ID card',
                      icon: Icons.person_outline_rounded,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Full name is required';
                        if (v.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    _buildInputField(
                      controller: _aadharController,
                      label: 'Aadhar Number',
                      hint: 'XXXX XXXX XXXX (12 digits)',
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                        _AadharFormatter(),
                      ],
                      validator: (v) {
                        final digits = (v ?? '').replaceAll(' ', '');
                        if (digits.isEmpty) return 'Aadhar number is required';
                        if (digits.length != 12) return 'Aadhar must be exactly 12 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingM),

                    _buildInputField(
                      controller: _voterIdController,
                      label: 'Voter ID Number',
                      hint: 'e.g. ABC1234567',
                      icon: Icons.how_to_vote_outlined,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(20),
                        _UpperCaseFormatter(),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Voter ID is required';
                        if (v.trim().length < 6) return 'Enter a valid Voter ID (min 6 chars)';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppDimensions.paddingL),

                    _buildCaptchaSection(),
                    const SizedBox(height: AppDimensions.paddingL),

                    if (kIsWeb && _webAuthnAvailable) ...[
                      _buildWebAuthnEnrollCard(),
                      const SizedBox(height: AppDimensions.paddingL),
                    ],

                    if (!kIsWeb && _biometricAvailable) ...[
                      _buildBiometricEnrollCard(),
                      const SizedBox(height: AppDimensions.paddingL),
                    ],

                    _buildTermsRow(),
                    const SizedBox(height: AppDimensions.paddingXL),

                    _buildSubmitButton(),
                  ]),
                ),
              ),

              const SizedBox(height: AppDimensions.paddingXL),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: _buildLoginLink(),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 20, offset: const Offset(0, 10),
          )],
        ),
        child: const Icon(Icons.how_to_vote_rounded, size: 40, color: AppColors.textWhite),
      ),
      const SizedBox(height: AppDimensions.paddingM),
      Text('Create Account', style: AppTextStyles.h2, textAlign: TextAlign.center),
      const SizedBox(height: AppDimensions.paddingXS),
      Text(
        'Register to participate in secure elections',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
    ]);
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 4),
        )],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surface,
          errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildCaptchaSection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10, offset: const Offset(0, 4),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.shield_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Text('Security Check',
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
        const SizedBox(height: AppDimensions.paddingS),

        // Captcha code box + refresh
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(color: AppColors.primary.withOpacity(0.25)),
              ),
              child: Text(
                _captchaQuestion,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.paddingS),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.primary,
            tooltip: 'New code',
            onPressed: _refreshCaptcha,
          ),
        ]),
        const SizedBox(height: AppDimensions.paddingS),

        // Code input
        TextFormField(
          controller: _captchaInputController,
          keyboardType: TextInputType.text,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: InputDecoration(
            labelText: 'Type the code above',
            prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(color: AppColors.primary.withOpacity(0.2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
        ),
      ]),
    );
  }

  Widget _buildTermsRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Checkbox(
        value: _agreeToTerms,
        activeColor: AppColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
      ),
      Expanded(
        child: Text.rich(TextSpan(
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          children: [
            const TextSpan(text: 'I agree to the '),
            WidgetSpan(child: GestureDetector(
              onTap: _showTerms,
              child: Text('Terms & Conditions',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  )),
            )),
            const TextSpan(text: ' and '),
            WidgetSpan(child: GestureDetector(
              onTap: _showPrivacy,
              child: Text('Privacy Policy',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  )),
            )),
          ],
        )),
      ),
    ]);
  }

  Widget _buildBiometricEnrollCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: _biometricEnrolled
            ? AppColors.success.withOpacity(0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
            color: _biometricEnrolled
                ? AppColors.success.withOpacity(0.5)
                : AppColors.primary.withOpacity(0.2),
            width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (_biometricEnrolled ? AppColors.success : AppColors.primary).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Icon(Icons.fingerprint_rounded,
                  color: _biometricEnrolled
                      ? AppColors.success
                      : Color.lerp(AppColors.primary, AppColors.primaryLight, _pulseCtrl.value),
                  size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Fingerprint Verification *',
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(
              _biometricEnrolled
                  ? 'Enrolled ✓ — Fingerprint login is ready'
                  : 'Fingerprint scan required to register',
              style: AppTextStyles.bodySmall.copyWith(
                  color: _biometricEnrolled ? AppColors.success : AppColors.textSecondary),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('Required',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
        if (!_biometricEnrolled) ...[
          const SizedBox(height: AppDimensions.paddingM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scanForEnrollment,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS))),
              icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
              label: Text('Tap to Scan Fingerprint',
                  style: AppTextStyles.button.copyWith(color: AppColors.primary, fontSize: 14)),
            ),
          ),
        ],
        if (_biometricEnrolled) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(
                  'Fingerprint enrolled. Use it to log in quickly.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      height: AppDimensions.buttonHeightL,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.35),
          blurRadius: 14, offset: const Offset(0, 7),
        )],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _register,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.textWhite),
                ))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.app_registration_rounded, color: AppColors.textWhite, size: 20),
              const SizedBox(width: AppDimensions.paddingS),
              Text('Create Account',
                  style: AppTextStyles.button.copyWith(color: AppColors.textWhite)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Column(children: [
      const Divider(),
      const SizedBox(height: AppDimensions.paddingXS),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Already have an account? ', style: AppTextStyles.bodyMedium),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Login', style: AppTextStyles.button.copyWith(
              color: AppColors.primary, fontSize: 14)),
        ),
      ]),
    ]);
  }

  // ── Dialogs ──────────────────────────────────────────────────
  void _showTerms() => showDialog(context: context, builder: (_) => _infoDialog(
    title: 'Terms & Conditions',
    sections: [
      ('1. Eligibility', 'You must hold a valid Indian Voter ID and Aadhar to register.'),
      ('2. One Vote Per Election', 'Each account may cast exactly one vote per election.'),
      ('3. Data Accuracy', 'Providing false Aadhar or Voter ID information is prohibited.'),
      ('4. Vote Privacy', 'Your vote choice is encrypted and never linked to your identity.'),
      ('5. Immutability', 'Votes recorded on blockchain cannot be altered or deleted.'),
      ('6. Account Security', 'You are responsible for keeping your Voter ID confidential.'),
    ],
  ));

  void _showPrivacy() => showDialog(context: context, builder: (_) => _infoDialog(
    title: 'Privacy Policy',
    sections: [
      ('Data Collected', 'Name, Aadhar (encrypted), Voter ID, optional email, and device info.'),
      ('Vote Anonymity', 'Vote choices are stored separately from identity — never linked.'),
      ('Data Sharing', 'We do not sell or share personal data with any third parties.'),
      ('Security', 'Aadhar numbers are hashed before storage using industry-standard encryption.'),
      ('Your Rights', 'Request account deletion or data export at: privacy@omnivote.io'),
    ],
  ));

  Widget _infoDialog({required String title, required List<(String, String)> sections}) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
      title: Text(title, style: AppTextStyles.h4),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: sections.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.$1, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(s.$2, style: AppTextStyles.bodySmall.copyWith(height: 1.5, color: AppColors.textSecondary)),
            ]),
          )).toList(),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          ),
          child: const Text('Close', style: TextStyle(color: AppColors.textWhite)),
        ),
      ],
    );
  }

  Widget _buildWebAuthnEnrollCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: _webAuthnEnrolled
            ? AppColors.success.withOpacity(0.07)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
            color: _webAuthnEnrolled
                ? AppColors.success.withOpacity(0.5)
                : AppColors.primary.withOpacity(0.2),
            width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: (_webAuthnEnrolled ? AppColors.success : AppColors.primary).withOpacity(0.10),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.fingerprint_rounded,
                color: _webAuthnEnrolled ? AppColors.success : AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Web Fingerprint *',
                style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            Text(
              _webAuthnEnrolled
                  ? 'Enrolled ✓ — Web fingerprint ready'
                  : 'Scan your fingerprint in the browser',
              style: AppTextStyles.bodySmall.copyWith(
                  color: _webAuthnEnrolled ? AppColors.success : AppColors.textSecondary),
            ),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Text('Required',
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11)),
          ),
        ]),
        if (!_webAuthnEnrolled) ...[
          const SizedBox(height: AppDimensions.paddingM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _registerWebAuthn,
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS))),
              icon: const Icon(Icons.fingerprint_rounded, color: AppColors.primary),
              label: Text('Register Fingerprint',
                  style: AppTextStyles.button.copyWith(color: AppColors.primary, fontSize: 14)),
            ),
          ),
        ],
        if (_webAuthnEnrolled) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
              const SizedBox(width: 8),
              Text('Fingerprint registered for this browser',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _AadharFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
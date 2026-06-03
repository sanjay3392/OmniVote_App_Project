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
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _voterIdController      = TextEditingController();
  final _captchaInputController = TextEditingController();

  bool _isLoading          = false;
  bool _isBioLoading       = false;
  bool _biometricAvailable = false;
  bool _webAuthnAvailable  = false;
  bool _isNewDevice        = false; // true when this device has no enrolled fingerprint
  final BiometricService _bio = BiometricService();
  late AnimationController _pulseCtrl;

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
    const upper  = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lower  = 'abcdefghjkmnpqrstuvwxyz';
    const digits = '23456789';
    const all    = upper + lower + digits;
    final rng = Random();
    // At least one uppercase, one lowercase, one digit
    final chars = [
      upper[rng.nextInt(upper.length)],
      lower[rng.nextInt(lower.length)],
      digits[rng.nextInt(digits.length)],
      all[rng.nextInt(all.length)],
      all[rng.nextInt(all.length)],
      all[rng.nextInt(all.length)],
    ]..shuffle(rng);
    final code = chars.join();
    setState(() {
      _captchaQuestion = code;
      _captchaAnswer   = code; // case-sensitive match
      _captchaInputController.clear();
    });
  }

  @override
  void dispose() {
    _voterIdController.dispose();
    _captchaInputController.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final voterId = _voterIdController.text.trim().toUpperCase();

    if (voterId.isEmpty) {
      _showSnack('Please enter your Voter ID Number.');
      return;
    }
    if (voterId.length < 6) {
      _showSnack('Please enter a valid Voter ID (minimum 6 characters).');
      return;
    }
    if (_captchaInputController.text.trim() != _captchaAnswer) {
      _showSnack('Incorrect security code. Please try again.');
      _refreshCaptcha();
      return;
    }

    // If biometric hardware available — try fingerprint login first
    if (!kIsWeb && _biometricAvailable) {
      final bioResult = await _bio.authenticate(
        reason: 'Scan your fingerprint to log in to OmniVote',
      );
      if (!mounted) return;
      if (!bioResult.success) {
        _showSnack(bioResult.errorMessage ?? 'Fingerprint required to log in.');
        return;
      }
      setState(() => _isLoading = true);
      try {
        final api = await OmniVoteApi.init();
        final user = await api.auth.biometricLogin(voterIdNumber: voterId);
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
              (route) => false,
        );
        return;
      } on ApiException catch (e) {
        if (e.statusCode == 403) {
          // Fingerprint not enrolled on THIS device — new device detected
          if (mounted) setState(() { _isNewDevice = true; _isLoading = false; });
          // Continue to normal login below, then offer re-enrollment after
        } else {
          _showSnack(e.message);
          _refreshCaptcha();
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      } catch (e) {
        _showSnack('Login failed. Please try again.');
        _refreshCaptcha();
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final api  = await OmniVoteApi.init();
      final user = await api.auth.login(voterIdNumber: voterId);

      if (!mounted) return;
      // If this is a new device, offer to enroll fingerprint before navigating
      if (_isNewDevice && _biometricAvailable) {
        setState(() => _isLoading = false);
        await _showNewDeviceEnrollDialog(api, user);
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
            (route) => false,
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
      _refreshCaptcha();
    } catch (e) {
      _showSnack('Login failed. Please try again.');
      _refreshCaptcha();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Called after successful normal login on a new device.
  Future<void> _showNewDeviceEnrollDialog(OmniVoteApi api, dynamic user) async {
    final enroll = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusL)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.phone_android_rounded,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text('New Device Detected',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your fingerprint is not enrolled on this device. '
                      'Enroll now to use fingerprint login here.',
                  style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.orange.shade800),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text(
            'Would you like to set up fingerprint login on this device?',
            style: AppTextStyles.bodyMedium,
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Skip',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
            ),
            icon: const Icon(Icons.fingerprint_rounded,
                color: AppColors.textWhite, size: 18),
            label: const Text('Enroll Fingerprint',
                style: TextStyle(color: AppColors.textWhite)),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (enroll == true) {
      final bioResult = await _bio.authenticate(
        reason: 'Scan your fingerprint to enable login on this device',
      );
      if (!mounted) return;
      if (bioResult.success) {
        try {
          await api.auth.enableBiometric('device_key');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Fingerprint enrolled on this device!'),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
          ));
        } catch (_) {}
      } else {
        _showSnack(bioResult.errorMessage ?? 'Fingerprint scan failed.');
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
          (route) => false,
    );
  }

  Future<void> _checkWebAuthn() async {
    final ok = await WebAuthnService.isAvailable();
    if (mounted) setState(() => _webAuthnAvailable = ok);
  }

  Future<void> _webAuthnLogin() async {
    final voterId = _voterIdController.text.trim().toUpperCase();
    if (voterId.isEmpty || voterId.length < 6) {
      _showSnack('Enter your Voter ID first.');
      return;
    }
    setState(() => _isBioLoading = true);
    try {
      final api = await OmniVoteApi.init();
      final challengeData = await api.auth.webAuthnLoginChallenge(voterIdNumber: voterId);
      final result = await WebAuthnService.authenticate(
        challenge: challengeData['challenge'] as String,
        credentialId: challengeData['credentialId'] as String,
        rpId: challengeData['rpId'] as String? ?? 'localhost',
      );
      if (!mounted) return;
      if (result['success'] != true) {
        _showSnack(result['error'] as String? ?? 'Fingerprint authentication failed.');
        return;
      }
      final user = await api.auth.webAuthnLoginVerify(
        voterIdNumber: voterId,
        credentialId: result['credentialId'] as String,
        clientDataJSON: result['clientDataJSON'] as String,
        signature: result['signature'] as String,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
            (r) => false,
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Error: ${e.toString().replaceAll("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isBioLoading = false);
    }
  }

  Future<void> _checkBiometric() async {
    final supported = await _bio.isDeviceSupported();
    final enrolled = await _bio.canCheckBiometrics();
    if (mounted) setState(() => _biometricAvailable = supported && enrolled);
  }

  Future<void> _biometricLogin() async {
    final voterId = _voterIdController.text.trim().toUpperCase();
    if (voterId.isEmpty || voterId.length < 6) {
      _showSnack('Enter your Voter ID first, then tap the fingerprint button.');
      return;
    }
    setState(() => _isBioLoading = true);
    try {
      final result = await _bio.authenticate(
        reason: 'Scan your fingerprint to log in to OmniVote',
      );
      if (!mounted) return;
      if (!result.success) {
        _showSnack(result.errorMessage ?? 'Fingerprint authentication failed.');
        return;
      }
      final api = await OmniVoteApi.init();
      final user = await api.auth.biometricLogin(voterIdNumber: voterId);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
            (r) => false,
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (e) {
      _showSnack('Biometric login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isBioLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusS)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimensions.paddingXL),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: AppDimensions.paddingXL),

              FadeInDown(child: _buildLogo()),
              const SizedBox(height: AppDimensions.paddingXL),

              FadeInUp(
                delay: const Duration(milliseconds: 150),
                child: Text(AppStrings.welcomeTitle,
                    style: AppTextStyles.h1, textAlign: TextAlign.center),
              ),
              const SizedBox(height: AppDimensions.paddingS),
              FadeInUp(
                delay: const Duration(milliseconds: 250),
                child: Text(
                  'Enter your Voter ID Number to cast your secure vote',
                  style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: AppDimensions.paddingXL * 1.5),

              FadeInUp(
                delay: const Duration(milliseconds: 350),
                child: _buildVoterIdField(),
              ),
              const SizedBox(height: AppDimensions.paddingM),

              FadeInUp(
                delay: const Duration(milliseconds: 450),
                child: _buildCaptchaSection(),
              ),
              const SizedBox(height: AppDimensions.paddingXL),

              FadeInUp(
                delay: const Duration(milliseconds: 550),
                child: _buildLoginButton(),
              ),

              // WebAuthn fingerprint login — web only
              if (kIsWeb && _webAuthnAvailable) ...[
                const SizedBox(height: AppDimensions.paddingM),
                FadeInUp(
                  delay: const Duration(milliseconds: 620),
                  child: _buildWebAuthnButton(),
                ),
                const SizedBox(height: 4),
                Text('Enter Voter ID above and verify with your browser fingerprint',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary)),
              ],

              // Fingerprint login — mobile only
              if (!kIsWeb && _biometricAvailable) ...[
                const SizedBox(height: AppDimensions.paddingM),
                FadeInUp(
                  delay: const Duration(milliseconds: 620),
                  child: _buildBiometricButton(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your Voter ID above and verify with fingerprint',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary),
                ),
              ],

              const SizedBox(height: AppDimensions.paddingXL),
              FadeInUp(
                delay: const Duration(milliseconds: 650),
                child: _buildTrustBadges(),
              ),

              const SizedBox(height: AppDimensions.paddingXL),
              FadeInUp(
                delay: const Duration(milliseconds: 750),
                child: _buildRegisterLink(),
              ),
              const SizedBox(height: AppDimensions.paddingL),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 100, height: 100,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 22, offset: const Offset(0, 10),
          )],
        ),
        child: const Icon(Icons.how_to_vote_rounded,
            size: 50, color: AppColors.textWhite),
      ),
    );
  }

  Widget _buildVoterIdField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10, offset: const Offset(0, 4),
        )],
      ),
      child: TextField(
        controller: _voterIdController,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [
          LengthLimitingTextInputFormatter(20),
          _UpperCaseFormatter(),
        ],
        onSubmitted: (_) => _login(),
        decoration: InputDecoration(
          labelText: 'Voter ID Number',
          hintText: 'e.g. ABC1234567',
          prefixIcon: const Icon(Icons.how_to_vote_outlined,
              color: AppColors.primary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surface,
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
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
        const SizedBox(height: AppDimensions.paddingS),

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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 8,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.primary,
            tooltip: 'New code',
            onPressed: _refreshCaptcha,
          ),
        ]),
        const SizedBox(height: AppDimensions.paddingS),

        TextField(
          controller: _captchaInputController,
          keyboardType: TextInputType.visiblePassword,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(6),
          ],
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: 'Type the code above',
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: AppColors.primary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusS),
              borderSide: BorderSide(
                  color: AppColors.primary.withOpacity(0.2)),
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

  Widget _buildLoginButton() {
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
          onTap: _isLoading ? null : _login,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Center(
            child: _isLoading
                ? const SizedBox(
                width: 24, height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textWhite),
                ))
                : Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.login_rounded,
                  color: AppColors.textWhite, size: 20),
              const SizedBox(width: AppDimensions.paddingS),
              Text('Login',
                  style: AppTextStyles.button.copyWith(
                      color: AppColors.textWhite)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTrustBadges() {
    final items = [
      (Icons.how_to_vote_outlined,  'Voter ID Login',     'Your unique Voter ID is your key'),
      (Icons.lock_outline_rounded,  'Anonymous Voting',   'Your choice stays private always'),
      (Icons.verified_outlined,     'Blockchain Secured', 'Immutable record on Solana'),
    ];
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            child: Icon(item.$1, color: AppColors.primary,
                size: AppDimensions.iconM),
          ),
          const SizedBox(width: AppDimensions.paddingM),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.$2,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
            Text(item.$3, style: AppTextStyles.bodySmall),
          ])),
        ]),
      )).toList(),
    );
  }

  Widget _buildBiometricButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.4), width: 1.5),
        boxShadow: [BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isBioLoading ? null : _biometricLogin,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: AppDimensions.paddingM),
            child: Center(
              child: _isBioLoading
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary)),
                const SizedBox(width: 10),
                Text('Scanning fingerprint…',
                    style: AppTextStyles.button.copyWith(
                        color: AppColors.primary)),
              ])
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedBuilder(
                  animation: _pulseCtrl,
                  builder: (_, __) => Icon(Icons.fingerprint_rounded,
                      color: Color.lerp(AppColors.primary,
                          AppColors.primaryLight, _pulseCtrl.value),
                      size: 24),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text('Login with Fingerprint',
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button.copyWith(
                          color: AppColors.primary)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Column(children: [
      const Divider(),
      const SizedBox(height: AppDimensions.paddingXS),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("Don't have an account? ", style: AppTextStyles.bodyMedium),
        TextButton(
          onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: Text('Register',
              style: AppTextStyles.button.copyWith(
                  color: AppColors.primary, fontSize: 14)),
        ),
      ]),
    ]);
  }

  Widget _buildWebAuthnButton() {
    return Container(
      height: AppDimensions.buttonHeightL,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: [BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isBioLoading ? null : _webAuthnLogin,
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
          child: Center(
            child: _isBioLoading
                ? Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.primary)),
              const SizedBox(width: 10),
              Text('Verifying fingerprint…',
                  style: AppTextStyles.button.copyWith(
                      color: AppColors.primary)),
            ])
                : Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.fingerprint_rounded,
                  color: AppColors.primary, size: 28),
              const SizedBox(width: 10),
              Text('Login with Fingerprint (Web)',
                  style: AppTextStyles.button.copyWith(
                      color: AppColors.primary)),
            ]),
          ),
        ),
      ),
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
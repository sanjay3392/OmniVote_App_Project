import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/storage_service.dart';
import '../auth/login_screen.dart';
import 'vote_history_screen.dart';
import 'help_support_screen.dart';
import 'terms_privacy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late User _user;
  bool _isBioLoading = false;
  final BiometricService _bio = BiometricService();

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Future<void> _enableBiometric() async {
    if (kIsWeb) return;
    setState(() => _isBioLoading = true);
    try {
      final result = await _bio.authenticate(
        reason: 'Scan your fingerprint to enable biometric login',
      );
      if (!mounted) return;
      if (!result.success) {
        _showSnack(result.errorMessage ?? 'Fingerprint scan failed.');
        return;
      }
      final api = await OmniVoteApi.init();
      await api.auth.enableBiometric('device_key');
      setState(() => _user = _user.copyWith(biometricEnabled: true));
      _showSnack('Biometric authentication enabled!', success: true);
    } catch (e) {
      _showSnack('Failed: ${e.toString().replaceAll("Exception: ", "")}');
    } finally {
      if (mounted) setState(() => _isBioLoading = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        ),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final storageService = await StorageService.init();
    await storageService.clearAll();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.backgroundGradient,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            const SizedBox(height: AppDimensions.paddingL),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                children: [
                  FadeInUp(
                    child: _buildUserInfo(),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _buildSecuritySection(),
                  ),
                  const SizedBox(height: AppDimensions.paddingL),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: _buildActionsSection(context),
                  ),
                  const SizedBox(height: AppDimensions.paddingXL),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = _user;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingXL),
      decoration: const BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        child: Column(
          children: [
            FadeInDown(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.textWhite,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person,
                  size: 50,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
            FadeInUp(
              child: Text(
                user.name ?? 'Anonymous Voter',
                style: AppTextStyles.h2.copyWith(
                  color: AppColors.textWhite,
                ),
              ),
            ),
            if (user.email != null) ...[
              const SizedBox(height: AppDimensions.paddingS),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  user.email!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textWhite.withOpacity(0.9),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppDimensions.paddingM),
            FadeInUp(
              delay: const Duration(milliseconds: 400),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.paddingM,
                  vertical: AppDimensions.paddingS,
                ),
                decoration: BoxDecoration(
                  color: AppColors.textWhite.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusCircle),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_user,
                      size: AppDimensions.iconS,
                      color: AppColors.textWhite,
                    ),
                    const SizedBox(width: AppDimensions.paddingXS),
                    Text(
                      'DID Verified',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    final user = _user;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account Information',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          const Divider(),
          const SizedBox(height: AppDimensions.paddingM),
          _buildInfoRow(
            icon: Icons.fingerprint,
            label: 'Decentralized ID (DID)',
            value: '${user.did.substring(0, 20)}...',
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildInfoRow(
            icon: Icons.vpn_key,
            label: 'Public Key',
            value: '${user.publicKey.substring(0, 20)}...',
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'Member Since',
            value: '${user.createdAt.day}/${user.createdAt.month}/${user.createdAt.year}',
          ),
          if (user.lastLogin != null) ...[
            const SizedBox(height: AppDimensions.paddingM),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Last Login',
              value: '${user.lastLogin!.day}/${user.lastLogin!.month}/${user.lastLogin!.year}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          const Divider(),
          const SizedBox(height: AppDimensions.paddingM),
          _buildSecurityItem(
            icon: Icons.fingerprint,
            title: 'Biometric Authentication',
            subtitle: _user.biometricEnabled ? 'Enabled' : 'Tap to enable',
            onTap: (!kIsWeb && !_user.biometricEnabled) ? _enableBiometric : null,
            trailing: _isBioLoading
                ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : Icon(
              _user.biometricEnabled ? Icons.check_circle : Icons.cancel,
              color: _user.biometricEnabled ? AppColors.success : AppColors.error,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildSecurityItem(
            icon: Icons.lock,
            title: 'End-to-End Encryption',
            subtitle: 'Active',
            trailing: const Icon(
              Icons.check_circle,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildSecurityItem(
            icon: Icons.verified_user,
            title: 'Zero-Knowledge Proofs',
            subtitle: 'Enabled',
            trailing: const Icon(
              Icons.check_circle,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    final user = _user;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Actions',
            style: AppTextStyles.h4,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          const Divider(),
          const SizedBox(height: AppDimensions.paddingM),
          _buildActionItem(
            icon: Icons.history,
            title: 'Vote History',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const VoteHistoryScreen())),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildActionItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HelpSupportScreen())),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildActionItem(
            icon: Icons.description,
            title: 'Terms & Privacy',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TermsPrivacyScreen())),
          ),
          const SizedBox(height: AppDimensions.paddingM),
          _buildActionItem(
            icon: Icons.logout,
            title: 'Logout',
            textColor: AppColors.error,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Icon(
            icon,
            size: AppDimensions.iconM,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFamily: value.contains('...') ? 'monospace' : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final row = Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusS),
          ),
          child: Icon(
            icon,
            size: AppDimensions.iconM,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppDimensions.paddingM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? AppColors.textPrimary,
              size: AppDimensions.iconM,
            ),
            const SizedBox(width: AppDimensions.paddingM),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
              size: AppDimensions.iconM,
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

class TermsPrivacyScreen extends StatefulWidget {
  const TermsPrivacyScreen({super.key});

  @override
  State<TermsPrivacyScreen> createState() => _TermsPrivacyScreenState();
}

class _TermsPrivacyScreenState extends State<TermsPrivacyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _buildTerms(),
          _buildPrivacy(),
        ],
      ),
    );
  }

  Widget _buildTerms() {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        _section('Last Updated', 'March 2026'),
        _section('1. Acceptance of Terms',
            'By registering and using OmniVote, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the application.'),
        _section('2. Eligibility',
            'You must be a registered voter with a valid Voter ID Number and Aadhar number to use OmniVote. You must be of legal voting age in your jurisdiction. Only one account per voter is permitted.'),
        _section('3. Account Security',
            'You are responsible for maintaining the confidentiality of your Voter ID and biometric credentials. You agree to notify us immediately of any unauthorized use of your account. You must not share your login credentials with any other person.'),
        _section('4. Voting Rules',
            'Each eligible voter may cast only one vote per election. Votes are final and cannot be changed or withdrawn once submitted. Attempting to cast multiple votes or manipulate the voting process is strictly prohibited and may result in permanent account suspension.'),
        _section('5. Prohibited Activities',
            'You may not: attempt to interfere with the voting system; use automated tools or bots; impersonate another voter; tamper with blockchain records; reverse engineer or decompile the application.'),
        _section('6. Blockchain Records',
            'All votes are permanently recorded on the Solana blockchain. These records are immutable and cannot be altered or deleted by any party, including OmniVote administrators. This ensures the integrity and transparency of all elections.'),
        _section('7. Disclaimer',
            'OmniVote is provided "as is" without warranties of any kind. We strive for 100% uptime during active elections but cannot guarantee uninterrupted service. We are not liable for any damages arising from the use of the application.'),
        _section('8. Changes to Terms',
            'We may update these terms from time to time. Continued use of OmniVote after changes are posted constitutes acceptance of the new terms.'),
        _section('9. Contact',
            'For questions about these Terms of Service, please contact us at legal@omnivote.app'),
        const SizedBox(height: AppDimensions.paddingL),
      ],
    );
  }

  Widget _buildPrivacy() {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      children: [
        _section('Last Updated', 'March 2026'),
        _section('1. Information We Collect',
            'We collect: your name, Voter ID Number, and Aadhar number (encrypted) during registration; your device identifier for biometric authentication; voting activity (election ID and timestamp — not your candidate choice); IP address and device information for security purposes.'),
        _section('2. How We Use Your Information',
            'Your personal information is used to: verify your identity and eligibility to vote; prevent duplicate voting; maintain the security of the platform; generate anonymized analytics about election participation.'),
        _section('3. Vote Secrecy',
            'OmniVote uses Zero-Knowledge Proofs to ensure your specific vote choice is never stored or transmitted in plain form. The blockchain records only that a valid vote was cast — your candidate selection is mathematically hidden.'),
        _section('4. Data Storage',
            'Personal data is stored in encrypted form on secure servers. Your Aadhar number is hashed and never stored in plain text. Biometric data (fingerprint) is processed locally on your device and never transmitted to our servers.'),
        _section('5. Decentralized Identity',
            'OmniVote uses Decentralized Identifiers (DIDs) and public-key cryptography. Your DID is generated locally and used to sign transactions. We never have access to your private key.'),
        _section('6. Data Sharing',
            'We do not sell your personal data. We do not share your data with third parties except: election authorities for eligibility verification; law enforcement when legally required. Blockchain transaction data is public by nature.'),
        _section('7. Data Retention',
            'Your account data is retained as long as your account is active. You may request deletion of your account and personal data at any time by contacting support. Blockchain records cannot be deleted due to the immutable nature of distributed ledgers.'),
        _section('8. Security',
            'We implement industry-standard security measures including: AES-256 encryption for stored data; TLS 1.3 for data in transit; biometric authentication; rate limiting and anomaly detection to prevent attacks.'),
        _section('9. Your Rights',
            'You have the right to: access the personal data we hold about you; request correction of inaccurate data; request deletion of your account; opt out of non-essential communications. To exercise these rights, contact privacy@omnivote.app'),
        _section('10. Contact Us',
            'For privacy concerns or data requests: Email: privacy@omnivote.app\nAddress: Election Technology Division, India'),
        const SizedBox(height: AppDimensions.paddingL),
      ],
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.primary)),
        const SizedBox(height: 6),
        Text(body,
            style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary, height: 1.6)),
      ]),
    );
  }
}
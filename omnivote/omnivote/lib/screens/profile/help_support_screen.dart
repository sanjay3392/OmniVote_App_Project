import 'package:flutter/material.dart';
import '../../constants/app_constants.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _faqs = [
    _FAQ('How do I cast my vote?',
        'Go to the Home screen, select an active election, choose your preferred candidate, verify with your fingerprint, and tap Confirm Vote. Your vote is instantly recorded on the blockchain.'),
    _FAQ('Is my vote anonymous?',
        'Yes. Your vote is secured using Zero-Knowledge Proofs. The blockchain records that you voted, but your specific choice is cryptographically hidden — even admins cannot see who you voted for.'),
    _FAQ('What is the blockchain receipt?',
        'After voting, you receive a unique transaction hash — a permanent record on the Solana blockchain proving your vote was counted. You can use this hash to independently verify your vote was recorded.'),
    _FAQ('Why is fingerprint required to vote?',
        'Biometric authentication ensures that only you can cast your vote, preventing unauthorized use of your account. You set this up during registration.'),
    _FAQ('Can I change my vote after casting?',
        'No. Once a vote is recorded on the blockchain it is permanent and immutable. This protects election integrity and prevents vote manipulation.'),
    _FAQ('What if I forget my Voter ID?',
        'Your Voter ID was provided during registration. Please contact your election authority or check your registration confirmation to retrieve it.'),
    _FAQ('Why is an election showing as "Closed"?',
        'Elections are only active during their scheduled voting window. Once the end date passes, the election closes automatically and results are published.'),
    _FAQ('Is my personal data secure?',
        'Yes. Your Aadhar number and personal details are encrypted end-to-end. OmniVote uses decentralized identifiers (DIDs) so your identity is never directly linked to your vote on the blockchain.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Help & Support'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('How can we help?',
                      style: AppTextStyles.h3.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Find answers to common questions below',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withOpacity(0.85))),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          Text('Frequently Asked Questions',
              style: AppTextStyles.h3),
          const SizedBox(height: 12),

          ..._faqs.map((f) => _buildFAQ(f)).toList(),

          const SizedBox(height: 20),

          // Contact card
          Container(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppDimensions.radiusM),
              border: Border.all(color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Still need help?',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _contactRow(Icons.email_outlined, 'Email Support',
                  'support@omnivote.app'),
              const SizedBox(height: 10),
              _contactRow(Icons.phone_outlined, 'Helpline',
                  '1800-XXX-XXXX (Toll Free)'),
              const SizedBox(height: 10),
              _contactRow(Icons.access_time, 'Support Hours',
                  'Mon–Fri, 9 AM – 6 PM IST'),
            ]),
          ),
          const SizedBox(height: AppDimensions.paddingL),
        ],
      ),
    );
  }

  Widget _buildFAQ(_FAQ faq) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusM),
            border: Border.all(color: AppColors.primary.withOpacity(0.1)),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(
                AppDimensions.paddingM, 0, AppDimensions.paddingM, AppDimensions.paddingM),
            leading: Icon(Icons.help_outline, color: AppColors.primary, size: 20),
            title: Text(faq.question,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            children: [
              Text(faq.answer,
                  style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.bodySmall
            .copyWith(fontWeight: FontWeight.w600)),
      ]),
    ]);
  }
}

class _FAQ {
  final String question;
  final String answer;
  const _FAQ(this.question, this.answer);
}
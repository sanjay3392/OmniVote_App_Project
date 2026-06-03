import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../../services/biometric_service.dart';
import '../../services/webauthn_service.dart';
import 'vote_confirmation_screen.dart';

class VotingScreen extends StatefulWidget {
  final Election election;
  final User user;

  const VotingScreen({
    super.key,
    required this.election,
    required this.user,
  });

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen>
    with SingleTickerProviderStateMixin {
  Candidate? _selectedCandidate;
  bool _isLoading          = false;
  bool _biometricAvailable = false;
  bool _webAuthnAvailable  = false;
  final BiometricService _bio = BiometricService();
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _checkBiometric();
    if (kIsWeb) _checkWebAuthn();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _select(Candidate c) => setState(() => _selectedCandidate = c);

  void _showSnack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _checkWebAuthn() async {
    final ok = await WebAuthnService.isAvailable();
    if (mounted) setState(() => _webAuthnAvailable = ok);
  }

  Future<void> _checkBiometric() async {
    final supported = await _bio.isDeviceSupported();
    final enrolled = await _bio.canCheckBiometrics();
    if (mounted) setState(() => _biometricAvailable = supported && enrolled);
  }

  Future<void> _onConfirmTapped() async {
    if (_selectedCandidate == null) {
      _showSnack('Please select a candidate first.');
      return;
    }
    final ok = await _showConfirmDialog();
    if (ok != true) return;

    // Web WebAuthn verification
    if (kIsWeb && widget.user.biometricEnabled) {
      if (!_webAuthnAvailable) {
        _showSnack('Browser fingerprint required but not available. Use a supported browser.');
        return;
      }
      try {
        final api = await OmniVoteApi.init();
        final challengeData = await api.auth.webAuthnVoteChallenge();
        final result = await WebAuthnService.authenticate(
          challenge: challengeData['challenge'] as String,
          credentialId: challengeData['credentialId'] as String,
          rpId: challengeData['rpId'] as String? ?? 'localhost',
        );
        if (!mounted) return;
        if (result['success'] != true) {
          _showSnack(result['error'] as String? ?? 'Fingerprint required to cast your vote.');
          return;
        }
        await api.auth.webAuthnVoteVerify(
          credentialId: result['credentialId'] as String,
          clientDataJSON: result['clientDataJSON'] as String,
          signature: result['signature'] as String,
        );
        if (!mounted) return;
      } catch (e) {
        _showSnack('Fingerprint verification failed: ${e.toString().replaceAll("Exception: ", "")}');
        return;
      }
    }

    // Android fingerprint verification
    if (!kIsWeb && widget.user.biometricEnabled) {
      if (!_biometricAvailable) {
        _showSnack('No fingerprint enrolled on this device. Please go to Settings → Passwords & Security → Fingerprint to enroll.');
        return;
      }
      final bioResult = await _bio.authenticate(
        reason: 'Scan your fingerprint to confirm your vote',
      );
      if (!mounted) return;
      if (!bioResult.success) {
        _showSnack(bioResult.errorMessage ?? 'Fingerprint required to cast your vote.');
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final api = await OmniVoteApi.init();
      final receipt = await api.votes.castVote(
        electionId: widget.election.id,
        candidateId: _selectedCandidate!.id,
        biometricVerified: !kIsWeb && widget.user.biometricEnabled && _biometricAvailable,
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 380),
          pageBuilder: (_, __, ___) => VoteConfirmationScreen(
            vote: Vote(
              id: receipt.id,
              electionId: widget.election.id,
              candidateId: _selectedCandidate!.id,
              voterId: widget.user.did,
              transactionHash: receipt.transactionHash,
              timestamp: receipt.timestamp,
              status: VoteStatus.confirmed,
              zkProof: receipt.zkProof,
            ),
            election: widget.election,
            candidate: _selectedCandidate!,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
        ),
      );
    } on ApiException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Failed to cast vote. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool?> _showConfirmDialog() {
    final c = _selectedCandidate!;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: const Color(0xFF16162A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppColors.primary.withOpacity(0.28), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 48,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.18),
                      Colors.transparent
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.how_to_vote_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Confirm Your Vote',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        )),
                  ),
                ]),
              ),
              // body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(children: [
                  Text('You are casting your vote for:',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13)),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.18)),
                    ),
                    child: Row(children: [
                      _PartyAvatar(candidate: c, size: 54),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  )),
                              if (c.party != null) ...[
                                const SizedBox(height: 6),
                                _PartyChip(party: c.party!),
                              ],
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: AppColors.warning.withOpacity(0.22)),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning.withOpacity(0.9),
                          size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'This action is final and irreversible.',
                            style: TextStyle(
                              color: AppColors.warning.withOpacity(0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: BorderSide(
                              color: Colors.white.withOpacity(0.18)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Go Back',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w700,
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_rounded,
                                size: 15, color: Colors.white),
                            SizedBox(width: 7),
                            Text('Cast My Vote',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.election.candidates;
    final daysLeft =
    widget.election.endDate.difference(DateTime.now()).inDays.clamp(0, 999);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3FA),
      body: Column(children: [
        _buildHeader(candidates.length, daysLeft),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            itemCount: candidates.length,
            itemBuilder: (_, i) => FadeInUp(
              delay: Duration(milliseconds: 55 * i),
              duration: const Duration(milliseconds: 380),
              child: _CandidateCard(
                candidate: candidates[i],
                index: i,
                isSelected: _selectedCandidate?.id == candidates[i].id,
                onTap: () => _select(candidates[i]),
              ),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: _buildConfirmBar(),
    );
  }

  Widget _buildHeader(int count, int daysLeft) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3F3BC2), Color(0xFF6C63FF), Color(0xFF9188FF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 19),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text('Cast Your Vote',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2)),
              ),
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (_, __) => Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(99),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.22)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: Color.lerp(const Color(0xFF00D4AA),
                            Colors.white, _pulseCtrl.value),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text('LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        )),
                  ]),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.account_balance_rounded,
                          color: Colors.white.withOpacity(0.6), size: 11),
                      const SizedBox(width: 5),
                      Text(widget.election.organizationName,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          )),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Text(widget.election.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                        letterSpacing: -0.5,
                      )),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _StatPill(
                          icon: Icons.people_outline_rounded,
                          label: '$count Candidates'),
                      _StatPill(
                          icon: Icons.timer_outlined, label: '$daysLeft days left'),
                      const _StatPill(
                          icon: Icons.how_to_reg_rounded, label: 'Select one'),
                    ],
                  ),
                  const SizedBox(height: 18),
                ]),
          ),
          ClipPath(
            clipper: _WaveClipper(),
            child: Container(height: 26, color: const Color(0xFFF1F3FA)),
          ),
        ]),
      ),
    );
  }

  Widget _buildConfirmBar() {
    final active = _selectedCandidate != null && !_isLoading;
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 20,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _selectedCandidate == null
              ? const SizedBox.shrink()
              : Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.07),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.18)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.primary, size: 15),
              const SizedBox(width: 8),
              Text('Selected: ',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.65),
                    fontSize: 12,
                  )),
              Expanded(
                child: Text(
                  _selectedCandidate!.name +
                      (_selectedCandidate!.party != null
                          ? '  \u00b7  ${_selectedCandidate!.party}'
                          : ''),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ]),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: active
                ? const LinearGradient(
              colors: [Color(0xFF3F3BC2), Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
                : null,
            color: active ? null : const Color(0xFFDFE3F0),
            boxShadow: active
                ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.38),
                blurRadius: 18,
                offset: const Offset(0, 7),
              ),
            ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: active ? _onConfirmTapped : null,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.verified_user_rounded,
                      size: 20,
                      color: active
                          ? Colors.white
                          : const Color(0xFF9098B8)),
                  const SizedBox(width: 10),
                  Text('Confirm Vote',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                        color: active
                            ? Colors.white
                            : const Color(0xFF9098B8),
                      )),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_rounded, size: 10, color: Colors.grey.shade400),
          const SizedBox(width: 4),
          Text('Blockchain-secured \u00b7 Zero-knowledge proof',
              style:
              TextStyle(fontSize: 10, color: Colors.grey.shade400)),
        ]),
      ]),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// CANDIDATE CARD
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class _CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final int index;
  final bool isSelected;
  final VoidCallback onTap;

  const _CandidateCard({
    required this.candidate,
    required this.index,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withOpacity(0.16)
                : Colors.black.withOpacity(0.055),
            blurRadius: isSelected ? 22 : 10,
            offset: const Offset(0, 4),
            spreadRadius: isSelected ? 0 : -2,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: AppColors.primary.withOpacity(0.07),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              // serial number badge
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 26,
                height: 26,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFEEF0FA),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('${index + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF8890B8),
                      )),
                ),
              ),

              // party logo / avatar
              _PartyAvatar(
                candidate: candidate,
                size: 62,
                selected: isSelected,
              ),

              const SizedBox(width: 14),

              // name + party chip + description
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(candidate.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A3E),
                            letterSpacing: -0.2,
                          )),
                      if (candidate.party != null) ...[
                        const SizedBox(height: 5),
                        _PartyChip(party: candidate.party!),
                      ],
                      if (candidate.description != null) ...[
                        const SizedBox(height: 5),
                        Text(candidate.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF8890B0),
                              height: 1.4,
                            )),
                      ],
                    ]),
              ),

              const SizedBox(width: 10),

              // radio indicator
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: isSelected
                    ? Container(
                  key: const ValueKey('on'),
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF3F3BC2), Color(0xFF6C63FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 15),
                )
                    : Container(
                  key: const ValueKey('off'),
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFCDD3E8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// PARTY AVATAR
// Shows candidate.imageUrl if provided,
// otherwise a coloured rounded box with initial
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class _PartyAvatar extends StatelessWidget {
  final Candidate candidate;
  final double size;
  final bool selected;

  const _PartyAvatar({
    required this.candidate,
    required this.size,
    this.selected = false,
  });

  static const List<Color> _palette = [
    Color(0xFF6C63FF), Color(0xFFE74C3C), Color(0xFF2ECC71),
    Color(0xFF3498DB), Color(0xFFE67E22), Color(0xFF9B59B6),
    Color(0xFF1ABC9C), Color(0xFFF39C12),
  ];

  Color get _color {
    final key = candidate.party ?? candidate.name;
    final idx = key.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[idx];
  }

  String get _initial =>
      candidate.name.isNotEmpty ? candidate.name[0].toUpperCase() : '?';

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(size * 0.22);
    final hasImage =
        candidate.imageUrl != null && candidate.imageUrl!.isNotEmpty;

    Widget core = hasImage
        ? ClipRRect(
      borderRadius: r,
      child: Image.network(
        candidate.imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, prog) =>
        prog == null ? child : _fallback(r),
        errorBuilder: (_, __, ___) => _fallback(r),
      ),
    )
        : _fallback(r);

    if (selected) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22 - 2),
          child: core,
        ),
      );
    }

    return SizedBox(width: size, height: size, child: core);
  }

  Widget _fallback(BorderRadius r) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_color, _color.withOpacity(0.70)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: r,
    ),
    child: Center(
      child: Text(_initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          )),
    ),
  );
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// PARTY CHIP
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class _PartyChip extends StatelessWidget {
  final String party;

  static const List<Color> _palette = [
    Color(0xFF6C63FF), Color(0xFFE74C3C), Color(0xFF2ECC71),
    Color(0xFF3498DB), Color(0xFFE67E22), Color(0xFF9B59B6),
    Color(0xFF1ABC9C), Color(0xFFF39C12),
  ];

  const _PartyChip({required this.party});

  Color get _color {
    final idx = party.codeUnits.fold(0, (a, b) => a + b) % _palette.length;
    return _palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final c = _color;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: c.withOpacity(0.26)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(party,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c,
                  letterSpacing: 0.1,
                )),
          ),
        ]),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// STAT PILL  (header row)
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 12),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            )),
      ]),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// WAVE CLIPPER
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
class _WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..lineTo(0, 0)
    ..quadraticBezierTo(
        s.width * 0.25, s.height, s.width * 0.5, s.height * 0.45)
    ..quadraticBezierTo(s.width * 0.75, 0, s.width, s.height * 0.65)
    ..lineTo(s.width, 0)
    ..close();

  @override
  bool shouldReclip(_WaveClipper _) => false;
}
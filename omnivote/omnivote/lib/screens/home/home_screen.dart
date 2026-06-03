import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../constants/app_constants.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';
import '../voting/voting_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  List<Election> _activeElections = [];
  List<Election> _upcomingElections = [];
  int _votesCast = 0;
  bool _isLoading = true;
  String? _error;
  final Map<String, bool> _votedMap = {};
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = await OmniVoteApi.init();
      final results = await Future.wait([
        api.elections.getElections(status: 'active'),
        api.elections.getElections(status: 'pending'),
        api.votes.getMyVotes(),
        api.users.getProfile(),
      ]);

      final activeResult   = results[0] as ElectionListResult;
      final upcomingResult = results[1] as ElectionListResult;
      final myVotes        = results[2] as List<VoteHistoryItem>;
      final freshUser      = results[3] as User;

      final votedTitles = myVotes.map((v) => v.electionTitle).toSet();
      final Map<String, bool> votedMap = {};
      for (final e in activeResult.elections) {
        votedMap[e.id] = votedTitles.contains(e.title);
      }

      if (!mounted) return;
      setState(() {
        _activeElections   = activeResult.elections;
        _upcomingElections = upcomingResult.elections;
        _votesCast         = myVotes.length;
        _votedMap.addAll(votedMap);
        _currentUser       = freshUser;
        _isLoading         = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error     = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? _buildHomeContent()
          : ProfileScreen(user: widget.user),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHomeContent() {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildWelcomeCard(),
                  const SizedBox(height: AppDimensions.paddingXL),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _buildErrorCard()
                  else ...[
                      _buildSectionTitle(Icons.how_to_vote_outlined, 'Active Elections'),
                      const SizedBox(height: AppDimensions.paddingM),
                      if (_activeElections.isEmpty)
                        _buildEmptyState('No active elections right now.')
                      else
                        ..._activeElections.asMap().entries.map((entry) =>
                            FadeInUp(
                              delay: Duration(milliseconds: entry.key * 80),
                              child: _buildElectionCard(entry.value),
                            ),
                        ),
                      if (_upcomingElections.isNotEmpty) ...[
                        const SizedBox(height: AppDimensions.paddingXL),
                        _buildSectionTitle(Icons.schedule_outlined, 'Upcoming Elections'),
                        const SizedBox(height: AppDimensions.paddingM),
                        ..._upcomingElections.asMap().entries.map((entry) =>
                            FadeInUp(
                              delay: Duration(milliseconds: entry.key * 80),
                              child: _buildElectionCard(entry.value),
                            ),
                        ),
                      ],
                    ],
                  const SizedBox(height: AppDimensions.paddingXL),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        title: const Text(
          AppConfig.appName,
          style: TextStyle(color: AppColors.textWhite, fontWeight: FontWeight.bold),
        ),
        background: Container(
          decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.textWhite),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.textWhite.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, size: AppDimensions.iconL, color: AppColors.textWhite),
              ),
              const SizedBox(width: AppDimensions.paddingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textWhite.withOpacity(0.8),
                      ),
                    ),
                    Text(
                      widget.user.name ?? 'Voter',
                      style: AppTextStyles.h3.copyWith(color: AppColors.textWhite),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.paddingM),
          const Divider(color: Colors.white24),
          const SizedBox(height: AppDimensions.paddingS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatItem('Active', _isLoading ? '—' : '${_activeElections.length}'),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildStatItem('Votes Cast', _isLoading ? '—' : '$_votesCast'),
              Container(width: 1, height: 30, color: Colors.white24),
              _buildVerifiedStat(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h3.copyWith(color: AppColors.textWhite, fontSize: 20),
        ),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textWhite.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedStat() {
    final verified = _currentUser.isVerified;
    return Column(
      children: [
        Icon(
          verified ? Icons.verified_rounded : Icons.access_time_rounded,
          color: verified ? const Color(0xFF4ADE80) : Colors.orange,
          size: 22,
        ),
        const SizedBox(height: 2),
        Text(
          verified ? 'Verified' : 'Pending',
          style: AppTextStyles.bodySmall.copyWith(
            color: verified ? const Color(0xFF4ADE80) : Colors.orange,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          'ID',
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textWhite.withOpacity(0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: AppDimensions.iconM),
        const SizedBox(width: AppDimensions.paddingS),
        Text(title, style: AppTextStyles.h3),
      ],
    );
  }

  Widget _buildElectionCard(Election election) {
    final daysRemaining = election.endDate.difference(DateTime.now()).inDays;
    final hasVoted = _votedMap[election.id] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: hasVoted
            ? Border.all(color: AppColors.success.withOpacity(0.4), width: 1.5)
            : (!_currentUser.isVerified && election.isActive)
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: election.isActive && !hasVoted
              ? () async {
            if (!_currentUser.isVerified) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(children: [
                    Icon(Icons.lock_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(child: Text('Your ID is pending admin verification. You cannot vote until verified.')),
                  ]),
                  backgroundColor: Colors.orange.shade700,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  duration: const Duration(seconds: 4),
                ),
              );
              return;
            }
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VotingScreen(election: election, user: _currentUser),
              ),
            );
            _loadData();
          }
              : null,
          borderRadius: BorderRadius.circular(AppDimensions.radiusL),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingM),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusBadge(election, hasVoted),
                    const Spacer(),
                    Icon(_getElectionTypeIcon(election.type),
                        color: AppColors.primary, size: AppDimensions.iconM),
                  ],
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(election.title, style: AppTextStyles.h4),
                const SizedBox(height: AppDimensions.paddingXS),
                Text(
                  election.organizationName,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary),
                ),
                const SizedBox(height: AppDimensions.paddingS),
                Text(
                  election.description,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.paddingM),
                if (election.isActive && election.totalVotes > 0)
                  _buildLiveResults(election),
                const SizedBox(height: AppDimensions.paddingS),
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: AppDimensions.iconS, color: AppColors.textSecondary),
                    const SizedBox(width: AppDimensions.paddingXS),
                    Text('${election.totalVotes} votes cast',
                        style: AppTextStyles.bodySmall),
                    const Spacer(),
                    Icon(Icons.timer_outlined,
                        size: AppDimensions.iconS, color: AppColors.textSecondary),
                    const SizedBox(width: AppDimensions.paddingXS),
                    Text(
                      election.isActive
                          ? (daysRemaining > 0 ? '$daysRemaining days left' : 'Ends today')
                          : 'Starts in $daysRemaining days',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
                if (hasVoted) ...[
                  const SizedBox(height: AppDimensions.paddingS),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingS, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, size: 14, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'You have voted in this election',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Election election, bool hasVoted) {
    final String label;
    final Color color;
    if (hasVoted) {
      label = 'VOTED'; color = AppColors.success;
    } else if (election.isActive) {
      label = 'ACTIVE'; color = AppColors.success;
    } else {
      label = 'UPCOMING'; color = AppColors.warning;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingS, vertical: AppDimensions.paddingXS),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusS),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
            color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildLiveResults(Election election) {
    final sorted = List<Candidate>.from(election.candidates)
      ..sort((a, b) => b.voteCount.compareTo(a.voteCount));
    final top = sorted.take(3).toList();
    final total = election.totalVotes > 0 ? election.totalVotes : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart, size: 13, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Live Results (${election.totalVotes} votes)',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...top.map((c) {
          final pct = c.voteCount / total;
          final isLeading = c.id == sorted.first.id && c.voteCount > 0;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: isLeading ? FontWeight.w700 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (isLeading) const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                    Text('${c.voteCount}  ${(pct * 100).toStringAsFixed(1)}%',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLeading ? AppColors.primary : Colors.grey.shade400,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildErrorCard() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.paddingM),
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusL),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 40),
          const SizedBox(height: AppDimensions.paddingS),
          Text('Could not load elections',
              style: AppTextStyles.h4.copyWith(color: AppColors.error)),
          const SizedBox(height: AppDimensions.paddingXS),
          Text(
            _error ?? 'Check your connection and try again.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.paddingM),
          ElevatedButton.icon(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          message,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
      ),
    );
  }

  IconData _getElectionTypeIcon(ElectionType type) {
    switch (type) {
      case ElectionType.presidential: return Icons.account_balance;
      case ElectionType.corporate:    return Icons.business;
      case ElectionType.dao:          return Icons.hub;
      default:                        return Icons.how_to_vote;
    }
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_constants.dart';
import '../../services/api_service.dart';

class VoteHistoryScreen extends StatefulWidget {
  const VoteHistoryScreen({super.key});

  @override
  State<VoteHistoryScreen> createState() => _VoteHistoryScreenState();
}

class _VoteHistoryScreenState extends State<VoteHistoryScreen> {
  bool _isLoading = true;
  List<VoteHistoryItem> _votes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final api = await OmniVoteApi.init();
      final votes = await api.votes.getMyVotes();
      if (mounted) setState(() { _votes = votes; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() {
        _error = 'Failed to load vote history. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _copyHash(String hash) {
    Clipboard.setData(ClipboardData(text: hash));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Transaction hash copied'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Vote History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildError()
          : _votes.isEmpty
          ? _buildEmpty()
          : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline, size: 56, color: AppColors.error.withOpacity(0.6)),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadHistory,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
          ),
        ]),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.how_to_vote_outlined, size: 72,
              color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('No votes yet', style: AppTextStyles.h3
              .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Your voting history will appear here after you cast your first vote.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      itemCount: _votes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _buildVoteCard(_votes[i]),
    );
  }

  Widget _buildVoteCard(VoteHistoryItem v) {
    final statusColor = v.status == 'confirmed' || v.status == 'verified'
        ? AppColors.success
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row
        Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.how_to_vote_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(v.electionTitle ?? 'Unknown Election',
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(v.status, style: TextStyle(fontSize: 11,
                  color: statusColor, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        // Details
        _row(Icons.calendar_today_outlined, 'Voted on',
            _formatDate(v.timestamp)),
        const SizedBox(height: 8),
        _row(Icons.language, 'Network', v.network ?? 'Solana Mainnet'),
        const SizedBox(height: 8),
        // Transaction hash
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.tag, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Transaction Hash',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              GestureDetector(
                onTap: () => _copyHash(v.transactionHash),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${v.transactionHash.substring(0, 20)}...',
                      style: TextStyle(fontSize: 12, color: AppColors.primary,
                          fontFamily: 'monospace', fontWeight: FontWeight.w500),
                    ),
                  ),
                  Icon(Icons.copy, size: 14, color: AppColors.primary),
                ]),
              ),
            ]),
          ),
        ]),
      ]),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.textSecondary),
      const SizedBox(width: 8),
      Text('$label: ', style: AppTextStyles.bodySmall
          .copyWith(color: AppColors.textSecondary)),
      Expanded(child: Text(value,
          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600))),
    ]);
  }

  String _formatDate(DateTime dt) {
    return '${dt.day} ${_month(dt.month)} ${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _month(int m) => const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];
}
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/membership_remote_data_source.dart';
import '../../data/repositories/membership_repository_impl.dart';
import '../../domain/entities/membership_entity.dart';
import '../manager/auth_controller.dart';
import '../manager/membership_controller.dart';

class MembershipPage extends StatefulWidget {
  const MembershipPage({
    super.key,
    required this.authController,
    this.onNavigateToHome,
  });

  final AuthController authController;
  final VoidCallback? onNavigateToHome;

  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  late final MembershipController _controller;

  @override
  void initState() {
    super.initState();
    final remote = MembershipRemoteDataSource();
    final repository = MembershipRepositoryImpl(remote);
    _controller = MembershipController(repository, widget.authController);
    _controller.load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: _controller.load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader(
                    context,
                    'TÍCH ĐIỂM THÀNH VIÊN',
                    'Tải lại',
                  ),
                  const SizedBox(height: 20),
                  if (_controller.isLoading && _controller.membership == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  else if (_controller.errorMessage != null &&
                      _controller.membership == null)
                    _buildErrorState(context)
                  else ...[
                    if (_controller.membership != null)
                      _buildSummaryCard(context, _controller.membership!),
                    const SizedBox(height: 24),
                    _buildHistoryHeader(context),
                    const SizedBox(height: 12),
                    if (_controller.history.isEmpty)
                      _buildEmptyHistory(context)
                    else
                      ..._controller.history.map(_buildHistoryItem),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: widget.onNavigateToHome,
          child: Text(
            'SHUTTLE_X',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String action,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        GestureDetector(
          onTap: _controller.load,
          child: Text(
            action,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.primaryContainer),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(BuildContext context, MembershipEntity data) {
    final numberFormat = NumberFormat.decimalPattern('vi_VN');
    final percentFormat = NumberFormat('0.##');
    final tierName = data.tier.name.isEmpty ? 'MEMBER' : data.tier.name;
    final nextTier = data.nextTierName;
    final pointsToNext = data.pointsToNextTier;
    final progress = _calcProgress(data);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A3D2C), Color(0xFF0E1F18)],
        ),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  tierName,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${percentFormat.format(data.tier.discountPercent)}% ưu đãi',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Điểm hiện tại',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            numberFormat.format(data.currentPoints),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: AppColors.tertiary,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 12),
          Text(
            nextTier == null || pointsToNext <= 0
                ? 'Bạn đang ở hạng cao nhất'
                : 'Còn ${numberFormat.format(pointsToNext)} điểm để lên hạng $nextTier',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildMetricChip(
                context,
                label: 'TỔNG ĐIỂM',
                value: numberFormat.format(data.totalPoints),
              ),
              const SizedBox(width: 12),
              _buildMetricChip(
                context,
                label: 'ƯU ĐÃI',
                value: '${percentFormat.format(data.tier.discountPercent)}%',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            data.tier.benefits.isEmpty
                ? 'Quyền lợi sẽ được cập nhật sau.'
                : data.tier.benefits,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white60, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white70,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          'Lịch sử tích điểm',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const Spacer(),
        Text(
          '${_controller.history.length} giao dịch',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(MembershipHistoryEntity item) {
    final numberFormat = NumberFormat.decimalPattern('vi_VN');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final isPositive = item.points >= 0;
    final color = isPositive ? Colors.greenAccent : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive ? Icons.add_rounded : Icons.remove_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mapReason(item.reason),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateFormat.format(item.createdAt),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}${numberFormat.format(item.points)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              if (item.referenceId != null)
                Text(
                  '#${item.referenceId}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.loyalty_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Chưa có giao dịch tích điểm.',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(
              Icons.card_membership_outlined,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _controller.errorMessage ?? 'Không thể tải thông tin thành viên.',
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            TextButton(
              onPressed: _controller.load,
              child: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ),
    );
  }

  double _calcProgress(MembershipEntity data) {
    if (data.pointsToNextTier <= 0) {
      return 1.0;
    }
    final total = data.currentPoints + data.pointsToNextTier;
    if (total <= 0) {
      return 0.0;
    }
    return data.currentPoints / total;
  }

  String _mapReason(String reason) {
    switch (reason.toUpperCase()) {
      case 'EARNED_FROM_ORDER':
        return 'Tích điểm từ đơn hàng';
      case 'REFUNDED_ORDER':
        return 'Hoàn điểm từ trả hàng';
      case 'USED_FOR_DISCOUNT':
        return 'Dùng điểm giảm giá';
      default:
        return reason.replaceAll('_', ' ');
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/review_remote_data_source.dart';
import '../../domain/repositories/review_repository.dart';
import '../manager/auth_controller.dart';
import '../manager/review_controller.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';

class ReviewsPage extends StatefulWidget {
  const ReviewsPage({
    super.key,
    required this.authController,
    this.cartCountListenable,
    this.chatCountListenable,
    this.onOpenCart,
    this.onOpenChat,
    this.onOpenShopChat,
    this.onNavigateToHome,
  });

  final AuthController authController;
  final ValueNotifier<int>? cartCountListenable;
  final ValueNotifier<int>? chatCountListenable;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenShopChat;
  final VoidCallback? onNavigateToHome;

  @override
  State<ReviewsPage> createState() => _ReviewsPageState();
}

class _ReviewsPageState extends State<ReviewsPage> {
  late final ReviewController _controller;

  @override
  void initState() {
    super.initState();
    final remote = ReviewRemoteDataSource();
    final repository = ReviewRepositoryImpl(remote);
    _controller = ReviewController(repository, widget.authController);
    _controller.fetchMyReviews();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _controller.fetchMyReviews,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _buildTopBar(context),
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'LỊCH SỬ ĐÁNH GIÁ', 'Làm mới'),
              const SizedBox(height: 20),
              _buildSummaryIndicator(context),
              const SizedBox(height: 24),
              if (_controller.isLoading && _controller.reviews.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: CircularProgressIndicator(color: AppColors.secondary),
                  ),
                )
              else if (_controller.reviews.isEmpty)
                _buildEmptyState(context)
              else
                ..._controller.reviews.map((e) => _ReviewCard(
                  review: e,
                  onEdit: () => _showEditDialog(context, e),
                  onDelete: () => _confirmDelete(context, e),
                )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
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
        const Spacer(),
        if (widget.chatCountListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: widget.chatCountListenable!,
            builder: (_, count, __) {
              return ChatIconBubble(
                count: count,
                onTap: widget.onOpenShopChat,
                icon: Icons.chat_rounded,
              );
            },
          )
        else
          ChatIconBubble(
            count: 0,
            onTap: widget.onOpenShopChat,
            icon: Icons.chat_rounded,
          ),
        const SizedBox(width: 6),
        ChatIconBubble(count: 0, onTap: widget.onOpenChat),
        const SizedBox(width: 10),
        if (widget.cartCountListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: widget.cartCountListenable!,
            builder: (_, count, __) {
              return CartIconBubble(count: count, onTap: widget.onOpenCart);
            },
          )
        else
          const CartIconBubble(count: 0),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHighest,
          backgroundImage: widget.authController.userProfile?.avatar != null
              ? NetworkImage(widget.authController.userProfile!.avatar!)
              : null,
          child: widget.authController.userProfile?.avatar == null
              ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20)
              : null,
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
          onTap: _controller.fetchMyReviews,
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

  Widget _buildSummaryIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061D3D), Color(0xFF020611)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.tertiary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _controller.totalReviews.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.surfaceDim,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TỔNG SỐ ĐÁNH GIÁ',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 1.0,
                      ),
                ),
                Text(
                  'Bạn đã đóng góp ${_controller.totalReviews} nhận xét cho cộng đồng nhé!',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.rate_review_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Bạn chưa có đánh giá nào.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, dynamic review) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc muốn xóa đánh giá này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _controller.deleteReview(review.id);
      if (mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa đánh giá thành công')),
        );
      }
    }
  }

  Future<void> _showEditDialog(BuildContext context, dynamic review) async {
    // Mock edit dialog for demonstration
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chỉnh sửa đang được hoàn thiện')),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.review,
    required this.onEdit,
    required this.onDelete,
  });

  final dynamic review; // ReviewEntity
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(review.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              review.productImage,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1F4B5A), Color(0xFF0A172C)],
                  ),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: AppColors.secondary, size: 40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        review.productName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      dateStr,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) => Icon(
                    index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < review.rating ? AppColors.tertiary : AppColors.textSecondary,
                    size: 16,
                  )),
                ),
                const SizedBox(height: 14),
                Text(
                  review.comment,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _ActionButton(
                      icon: Icons.edit_outlined,
                      label: 'CHỈNH SỬA',
                      color: AppColors.secondary,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 24),
                    _ActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: 'XÓA BỎ',
                      color: Colors.redAccent,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('dd THMM, yyyy').format(dt).toUpperCase();
    } catch (_) {
      return '';
    }
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

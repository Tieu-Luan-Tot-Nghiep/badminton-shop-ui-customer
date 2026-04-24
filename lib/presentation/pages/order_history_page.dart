import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/order_entity.dart';
import '../manager/order_controller.dart';
import '../manager/auth_controller.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({
    super.key,
    required this.controller,
    required this.authController,
    this.onNavigateToHome,
  });

  final OrderController controller;
  final AuthController authController;
  final VoidCallback? onNavigateToHome;

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadOrders();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.controller,
          builder: (context, _) {
            final orders = widget.controller.orders;
            
            return RefreshIndicator(
              color: AppColors.secondary,
              onRefresh: widget.controller.loadOrders,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 24),
                  _buildSectionHeader(context, 'LỊCH SỬ ĐƠN HÀNG', 'Tải lại'),
                  const SizedBox(height: 20),
                  if (widget.controller.isLoading && orders.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: CircularProgressIndicator(color: AppColors.secondary),
                      ),
                    )
                  else if (widget.controller.errorMessage != null && orders.isEmpty)
                    _buildErrorState(context)
                  else if (orders.isEmpty)
                    _buildEmptyState(context)
                  else
                    ...orders.map((order) => _buildOrderCard(order)),
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
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
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
        const Spacer(),
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

  Widget _buildSectionHeader(BuildContext context, String title, String action) {
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        GestureDetector(
          onTap: widget.controller.loadOrders,
          child: Text(
            action,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.primaryContainer),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(Icons.receipt_long_rounded, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(widget.controller.errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
            TextButton(onPressed: widget.controller.loadOrders, child: const Text('THỬ LẠI')),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: const Text('Bạn chưa có đơn hàng nào.', style: TextStyle(color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _buildOrderCard(OrderEntity order) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MÃ ĐƠN: #${order.orderCode}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(dateFormat.format(order.createdAt), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(order.orderStatus),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          if (order.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      order.items.first.thumbnailUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceDim, width: 60, height: 60, child: const Icon(Icons.image_not_supported_rounded)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.items.first.productName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('Phân loại: ${order.items.first.variantName}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text('x${order.items.first.quantity}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (order.items.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text('Xem thêm ${order.items.length - 1} sản phẩm', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ),
            ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text('${order.items.length} sản phẩm', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ),
                Row(
                  children: [
                    const Text('Thành tiền: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(currencyFormat.format(order.totalAmount), style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryContainer, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;

    switch (status.toUpperCase()) {
      case 'PENDING':
        color = Colors.orangeAccent;
        text = 'CHỜ XÁC NHẬN';
        break;
      case 'CONFIRMED':
        color = Colors.blueAccent;
        text = 'ĐÃ XÁC NHẬN';
        break;
      case 'SHIPPING':
        color = Colors.cyanAccent;
        text = 'ĐANG GIAO';
        break;
      case 'DELIVERED':
        color = Colors.greenAccent;
        text = 'HOÀN THÀNH';
        break;
      case 'CANCELLED':
        color = Colors.redAccent;
        text = 'ĐÃ HỦY';
        break;
      default:
        color = AppColors.textSecondary;
        text = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }
}

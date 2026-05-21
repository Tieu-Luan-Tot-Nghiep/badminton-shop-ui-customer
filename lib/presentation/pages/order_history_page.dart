import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/order_entity.dart';
import '../../data/datasources/review_remote_data_source.dart';
import '../../domain/repositories/review_repository.dart';
import '../manager/order_controller.dart';
import '../manager/auth_controller.dart';
import '../manager/review_controller.dart';

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
  late final ReviewController _reviewController;

  @override
  void initState() {
    super.initState();
    final reviewRemote = ReviewRemoteDataSource();
    final reviewRepository = ReviewRepositoryImpl(reviewRemote);
    _reviewController = ReviewController(
      reviewRepository,
      widget.authController,
    );
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
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                        ),
                      ),
                    )
                  else if (widget.controller.errorMessage != null &&
                      orders.isEmpty)
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
        const Spacer(),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHighest,
          backgroundImage: widget.authController.userProfile?.avatar != null
              ? NetworkImage(widget.authController.userProfile!.avatar!)
              : null,
          child: widget.authController.userProfile?.avatar == null
              ? const Icon(
                  Icons.person_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                )
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
          onTap: widget.controller.loadOrders,
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

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            const Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              widget.controller.errorMessage!,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextButton(
              onPressed: widget.controller.loadOrders,
              child: const Text('THỬ LẠI'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: const Text(
          'Bạn chưa có đơn hàng nào.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
                      Text(
                        'MÃ ĐƠN: #${order.orderCode}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormat.format(order.createdAt),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
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
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceDim,
                        width: 60,
                        height: 60,
                        child: const Icon(Icons.image_not_supported_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items.first.productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Phân loại: ${order.items.first.variantName}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'x${order.items.first.quantity}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
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
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Xem thêm ${order.items.length - 1} sản phẩm',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${order.items.length} sản phẩm',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Text(
                          'Thành tiền: ',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(order.totalAmount),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryContainer,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (_canRequestReturn(order)) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _openReviewSheet(order),
                          icon: const Icon(Icons.rate_review_outlined),
                          label: const Text('Đánh giá'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openReturnRequestSheet(order),
                          icon: const Icon(Icons.assignment_return_rounded),
                          label: const Text('Yêu cầu trả hàng'),
                        ),
                      ),
                    ],
                  ),
                ] else if (_canCancelOrder(order)) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _openCancelOrderDialog(order),
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Hủy đơn hàng'),
                    ),
                  ),
                ] else if (_isReturnFlowStatus(order.orderStatus)) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Đơn hàng đang trong quy trình đổi/trả: ${order.orderStatus}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ] else if (_canReview(order)) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _openReviewSheet(order),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Đánh giá sản phẩm'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Text(
                    'Trạng thái hiện tại chưa hỗ trợ thao tác: ${order.orderStatus}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
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

    switch (_normalizedStatus(status)) {
      case 'PENDING':
      case 'CREATED':
      case 'AWAITING_PAYMENT':
      case 'WAITING_PAYMENT':
      case 'PENDING_PAYMENT':
      case 'WAITING_CONFIRMATION':
      case 'AWAITING_CONFIRMATION':
        color = Colors.orangeAccent;
        text = 'CHỜ XÁC NHẬN';
        break;
      case 'CONFIRMED':
      case 'PROCESSING':
        color = Colors.blueAccent;
        text = 'ĐÃ XÁC NHẬN';
        break;
      case 'SHIPPING':
      case 'OUT_FOR_DELIVERY':
        color = Colors.cyanAccent;
        text = 'ĐANG GIAO';
        break;
      case 'DELIVERED':
      case 'COMPLETED':
        color = Colors.greenAccent;
        text = 'HOÀN THÀNH';
        break;
      case 'RETURN_REQUESTED':
        color = Colors.orangeAccent;
        text = 'YÊU CẦU TRẢ HÀNG';
        break;
      case 'AWAITING_RETURN':
        color = Colors.blueAccent;
        text = 'CHỜ TRẢ HÀNG';
        break;
      case 'RETURN_RECEIVED':
        color = Colors.cyanAccent;
        text = 'ĐÃ NHẬN HÀNG TRẢ';
        break;
      case 'RETURNED':
        color = Colors.cyanAccent;
        text = 'ĐÃ TRẢ HÀNG';
        break;
      case 'REFUNDED':
        color = Colors.purpleAccent;
        text = 'ĐÃ HOÀN TIỀN';
        break;
      case 'CANCELLED':
      case 'CANCELED':
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _normalizedStatus(String status) {
    return status
        .trim()
        .toUpperCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool _canRequestReturn(OrderEntity order) {
    final hasValidOrderItemId = order.items.any(
      (item) => item.id > 0 && item.quantity > 0,
    );
    return _isDeliveredStatus(order.orderStatus) && hasValidOrderItemId;
  }

  bool _canCancelOrder(OrderEntity order) {
    return _isPreConfirmStatus(order.orderStatus);
  }

  bool _isDeliveredStatus(String status) {
    final normalized = _normalizedStatus(status);
    return normalized == 'DELIVERED' || normalized == 'COMPLETED';
  }

  bool _canReview(OrderEntity order) {
    final hasValidOrderItemId = order.items.any(
      (item) => item.id > 0 && item.quantity > 0,
    );
    return _isDeliveredStatus(order.orderStatus) && hasValidOrderItemId;
  }

  bool _isPreConfirmStatus(String status) {
    final normalized = _normalizedStatus(status);
    const allowed = <String>{
      'PENDING',
      'CREATED',
      'AWAITING_PAYMENT',
      'WAITING_PAYMENT',
      'PENDING_PAYMENT',
      'WAITING_CONFIRMATION',
      'AWAITING_CONFIRMATION',
    };
    return allowed.contains(normalized);
  }

  bool _isReturnFlowStatus(String status) {
    const statuses = <String>{
      'RETURN_REQUESTED',
      'AWAITING_RETURN',
      'RETURN_RECEIVED',
      'RETURNED',
      'REFUNDED',
      'REJECTED',
    };
    final normalized = _normalizedStatus(status);
    return statuses.contains(normalized) || normalized.contains('RETURN');
  }

  Future<void> _openReviewSheet(OrderEntity order) async {
    if (!_canReview(order)) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              top: 16,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Đánh giá sản phẩm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Chọn sản phẩm để đánh giá:'),
                    const SizedBox(height: 8),
                    ...order.items.map((item) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceContainer.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                item.thumbnailUrl,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  color: AppColors.surfaceDim,
                                  child: const Icon(
                                    Icons.image_not_supported_rounded,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.productName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _showReviewDialog(item),
                              child: const Text('Đánh giá'),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReviewDialog(OrderItemEntity item) async {
    final commentController = TextEditingController();
    double rating = 5;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              if (submitting) return;
              setDialogState(() => submitting = true);
              final ok = await _reviewController.createReview(
                item.id,
                rating,
                commentController.text.trim(),
              );
              if (!mounted) return;
              setDialogState(() => submitting = false);
              Navigator.of(dialogContext).pop();

              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Đã gửi đánh giá. Cảm ơn bạn!'
                        : (_reviewController.error ??
                              'Không thể gửi đánh giá. Vui lòng thử lại.'),
                  ),
                ),
              );
            }

            return AlertDialog(
              backgroundColor: AppColors.surfaceContainer,
              title: const Text('Đánh giá sản phẩm'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.productName),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(5, (index) {
                      final value = index + 1;
                      return IconButton(
                        onPressed: () =>
                            setDialogState(() => rating = value.toDouble()),
                        icon: Icon(
                          value <= rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: AppColors.tertiary,
                        ),
                        splashRadius: 18,
                      );
                    }),
                  ),
                  TextField(
                    controller: commentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Nhận xét',
                      hintText: 'Chia sẻ cảm nhận của bạn',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Hủy'),
                ),
                FilledButton(
                  onPressed: submitting ? null : submit,
                  child: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Gửi đánh giá'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openReturnRequestSheet(OrderEntity order) async {
    final reasonController = TextEditingController();
    final evidenceController = TextEditingController();
    final bankNameController = TextEditingController();
    final bankAccountNameController = TextEditingController();
    final bankAccountNumberController = TextEditingController();

    String refundMethod = 'BANK_TRANSFER';
    final selected = <int, bool>{for (final item in order.items) item.id: true};
    final quantities = <int, int>{
      for (final item in order.items) item.id: item.quantity,
    };
    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> submit() async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Vui lòng nhập lý do trả hàng.'),
                  ),
                );
                return;
              }

              final items = order.items
                  .where((item) => selected[item.id] == true)
                  .where((item) => item.id > 0)
                  .map(
                    (item) => {
                      'orderItemId': item.id,
                      'quantity': quantities[item.id] ?? item.quantity,
                    },
                  )
                  .toList();

              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Không tìm thấy orderItemId hợp lệ. Vui lòng tải lại đơn hàng rồi thử lại.',
                    ),
                  ),
                );
                return;
              }

              final evidenceUrls = evidenceController.text
                  .split(RegExp(r'\r?\n|,'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();

              final payload = <String, dynamic>{
                'reason': reason,
                'refundMethod': refundMethod,
                'items': items,
                if (evidenceUrls.isNotEmpty) 'evidenceUrls': evidenceUrls,
                if (refundMethod == 'BANK_TRANSFER') ...{
                  'bankAccountName': bankAccountNameController.text.trim(),
                  'bankAccountNumber': bankAccountNumberController.text.trim(),
                  'bankName': bankNameController.text.trim(),
                },
              };

              setModalState(() => submitting = true);
              final ok = await widget.controller.createReturnRequest(
                order.orderCode,
                payload,
              );
              if (!mounted || !context.mounted) {
                return;
              }
              setModalState(() => submitting = false);

              Navigator.of(context).pop();

              if (ok) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Đã gửi yêu cầu trả hàng.')),
                );
              } else {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      widget.controller.errorMessage ??
                          'Không thể gửi yêu cầu trả hàng.',
                    ),
                  ),
                );
              }
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  top: 16,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tạo yêu cầu trả hàng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Chọn sản phẩm cần trả:'),
                        const SizedBox(height: 8),
                        ...order.items.map((item) {
                          final isSelected = selected[item.id] ?? false;
                          final maxQty = item.quantity <= 0 ? 1 : item.quantity;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: AppColors.surfaceContainer.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) {
                                    setModalState(() {
                                      selected[item.id] = value ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    item.productName,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: (quantities[item.id] ?? maxQty).clamp(
                                    1,
                                    maxQty,
                                  ),
                                  items:
                                      List<int>.generate(
                                            maxQty,
                                            (index) => index + 1,
                                          )
                                          .map(
                                            (qty) => DropdownMenuItem<int>(
                                              value: qty,
                                              child: Text('x$qty'),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: isSelected
                                      ? (value) {
                                          if (value == null) return;
                                          setModalState(() {
                                            quantities[item.id] = value;
                                          });
                                        }
                                      : null,
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                        TextField(
                          controller: reasonController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Lý do trả hàng *',
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: refundMethod,
                          items: const [
                            DropdownMenuItem(
                              value: 'BANK_TRANSFER',
                              child: Text('BANK_TRANSFER'),
                            ),
                            DropdownMenuItem(
                              value: 'VNPAY',
                              child: Text('VNPAY'),
                            ),
                            DropdownMenuItem(value: 'COD', child: Text('COD')),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setModalState(() => refundMethod = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Phương thức hoàn tiền',
                          ),
                        ),
                        if (refundMethod == 'BANK_TRANSFER') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: bankAccountNameController,
                            decoration: const InputDecoration(
                              labelText: 'Tên chủ tài khoản',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: bankAccountNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Số tài khoản',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: bankNameController,
                            decoration: const InputDecoration(
                              labelText: 'Ngân hàng',
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        TextField(
                          controller: evidenceController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Evidence URLs (mỗi dòng 1 link hoặc ngăn cách dấu phẩy)',
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: submitting
                                    ? null
                                    : () => Navigator.of(context).pop(),
                                child: const Text('Hủy'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton(
                                onPressed: submitting ? null : submit,
                                child: submitting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Gửi yêu cầu'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // NOTE:
    // Do not dispose local controllers immediately after bottom sheet closes.
    // During route pop animation, TextField widgets may still read controllers,
    // causing "TextEditingController was used after being disposed".
  }

  Future<void> _openCancelOrderDialog(OrderEntity order) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hủy đơn hàng'),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Lý do hủy đơn *',
              hintText: 'Nhập lý do hủy đơn hàng',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  return;
                }
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Xác nhận hủy'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await widget.controller.cancelOrder(
        order.orderCode,
        reasonController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Đã hủy đơn hàng.'
                : (widget.controller.errorMessage ?? 'Không thể hủy đơn hàng.'),
          ),
        ),
      );
    }
  }
}

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/cart_remote_data_source.dart';
import '../manager/address_controller.dart';
import '../manager/auth_controller.dart';
import '../manager/cart_controller.dart';
import '../manager/order_controller.dart';
import '../widgets/app_shell.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';
import 'checkout_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({
    super.key,
    required this.authController,
    required this.addressController,
    required this.orderController,
    required this.selectedTabIndex,
    required this.onTabChanged,
    this.onOpenShop,
    this.onRequireLogin,
    this.onOpenChat,
    this.onNavigateToHome,
  });

  final AuthController authController;
  final AddressController addressController;
  final OrderController orderController;
  final int selectedTabIndex;
  final ValueChanged<int>? onTabChanged;
  final VoidCallback? onOpenShop;
  final VoidCallback? onRequireLogin;
  final VoidCallback? onOpenChat;
  final VoidCallback? onNavigateToHome;

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final CartController _controller;
  final Set<int> _selectedVariantIds = <int>{};
  bool _didInitSelection = false;

  @override
  void initState() {
    super.initState();
    if (!widget.authController.isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onRequireLogin?.call();
      });
    }
    _controller = CartController(CartRemoteDataSource(), widget.authController)
      ..load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        _syncSelectionWithItems(_controller.items);
        return AppShell(
          selectedIndex: widget.selectedTabIndex,
          onTabChanged: (index) {
            widget.onTabChanged?.call(index);
            Navigator.of(context).pop();
          },
          body: RefreshIndicator(
            color: AppColors.secondary,
            onRefresh: _controller.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
              children: [
                _buildTopBar(context),
                const SizedBox(height: 12),
                const SizedBox(height: 18),
                if (_controller.isLoading && _controller.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.secondary,
                      ),
                    ),
                  )
                else if (_controller.error != null && _controller.items.isEmpty)
                  _buildErrorCard(context)
                else if (_controller.items.isEmpty)
                  _buildEmptyState(context)
                else ...[
                  _buildSectionHeader(context, 'GIỎ HÀNG', _itemCountLabel),
                  const SizedBox(height: 10),
                  _buildSelectionRow(context),
                  const SizedBox(height: 8),
                  ..._controller.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCartItemCard(context, item),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildVoucherRow(context),
                ],
                const SizedBox(height: 22),
                _buildSectionHeader(context, 'THANH TOÁN', ''),
                const SizedBox(height: 10),
                _buildCheckoutPanel(context),
              ],
            ),
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
        ChatIconBubble(count: 0, onTap: widget.onOpenChat),
        const SizedBox(width: 10),
        CartIconBubble(count: _controller.totalQuantity),
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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontStyle: FontStyle.italic,
              fontSize: 23,
            ),
          ),
        ),
        Flexible(
          child: Text(
            action,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.primaryContainer,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

  String get _itemCountLabel {
    final count = _controller.totalQuantity;
    if (count <= 0) {
      return '0 SẢN PHẨM';
    }
    if (count > 999) {
      return '999+ SẢN PHẨM';
    }
    return '$count SẢN PHẨM';
  }



  Widget _buildErrorCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _controller.error ?? 'Không thể tải giỏ hàng',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontSize: 16),
          ),
          if ((_controller.debugErrorDetails ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceDim,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: SelectableText(
                _controller.debugErrorDetails!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: _controller.load,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.shopping_cart_checkout_rounded,
            size: 42,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 10),
          Text(
            'Giỏ hàng trống',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            'Thêm sản phẩm để bắt đầu đơn hàng đầu tiên.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: widget.onOpenShop,
            child: const Text('Đi đến Shop'),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, CartItemModel item) {
    final isBusy = _controller.isVariantBusy(item.variantId);
    final isSelected = _selectedVariantIds.contains(item.variantId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isSelected
              ? AppColors.primaryContainer.withValues(alpha: 0.55)
              : AppColors.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 104,
              height: 104,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: item.imageUrl == null || item.imageUrl!.isEmpty
                        ? Container(
                            color: AppColors.surfaceContainerHighest,
                            child: const Icon(
                              Icons.image_not_supported_outlined,
                            ),
                          )
                        : Image.network(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _buildSelectionBadge(
                      context,
                      isSelected: isSelected,
                      onTap: () => _toggleItem(item.variantId),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.productName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              fontSize: 17,
                            ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: isBusy ? null : () => _confirmRemoveItem(item),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.9,
                            ),
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item.specText.isEmpty
                      ? 'PHIÊN BẢN TIÊU CHUẨN'
                      : item.specText,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _buildQtyPill(
                        context,
                        quantity: item.quantity,
                        onDecrease: isBusy
                            ? null
                            : () => _controller.decrease(item),
                        onIncrease: isBusy
                            ? null
                            : () => _controller.increase(item),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          _formatPrice(item.lineTotal),
                          maxLines: 1,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: isSelected
                                    ? AppColors.secondary
                                    : AppColors.textSecondary,
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isBusy) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(minHeight: 2),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBadge(
    BuildContext context, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected
                ? AppColors.primaryContainer
                : AppColors.surfaceContainerHighest,
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryContainer
                  : AppColors.textSecondary.withValues(alpha: 0.65),
            ),
          ),
          child: Icon(
            isSelected ? Icons.check_rounded : Icons.add_rounded,
            size: 14,
            color: isSelected
                ? AppColors.onPrimaryContainer
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildQtyPill(
    BuildContext context, {
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback? onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _qtyButton(context, icon: Icons.remove, onTap: onDecrease),
            SizedBox(
              width: 34,
              child: Center(
                child: Text(
                  quantity.toString().padLeft(2, '0'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            _qtyButton(
              context,
              icon: Icons.add,
              filled: true,
              onTap: onIncrease,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionRow(BuildContext context) {
    final items = _controller.items;
    final allSelected =
        items.isNotEmpty && _selectedVariantIds.length == items.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (_) => _toggleSelectAll(),
            activeColor: AppColors.primaryContainer,
            checkColor: AppColors.onPrimaryContainer,
            side: const BorderSide(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              'Chọn tất cả (${_selectedVariantIds.length}/${items.length})',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontSize: 15),
            ),
          ),
          if (items.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 90),
              child: TextButton(
                onPressed: _confirmClearCart,
                child: const Text('Xóa hết', overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }

  Widget _qtyButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: filled
                ? AppColors.primaryContainer
                : AppColors.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 16,
            color: filled
                ? AppColors.onPrimaryContainer
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildVoucherRow(BuildContext context) {
    final discount = _controller.discountAmount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.confirmation_number_outlined,
            color: AppColors.primaryContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'MÃ GIẢM GIÁ',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                letterSpacing: 1,
                fontSize: 15,
              ),
            ),
          ),
          Text(
            discount > 0 ? '- ${_formatPrice(discount)}' : '- 0đ',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontWeight: FontWeight.w900,
              fontSize: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutPanel(BuildContext context) {
    final selectedCount = _selectedVariantIds.length;
    final selectedTotal = _selectedTotal;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TỔNG SỐ TIỀN',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 2,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Đã chọn $selectedCount sản phẩm',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _formatPrice(selectedTotal),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                fontSize: 40,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: selectedCount == 0
                ? null
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Sẵn sàng thanh toán $selectedCount sản phẩm.',
                        ),
                      ),
                    );
                  },
            borderRadius: BorderRadius.circular(999),
            child: Opacity(
              opacity: selectedCount == 0 ? 0.45 : 1,
              child: GestureDetector(
                onTap: selectedCount == 0 ? null : () => _navigateToCheckout(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      topRight: Radius.circular(99),
                      bottomRight: Radius.circular(99),
                    ),
                    gradient: LinearGradient(
                      colors: [AppColors.primaryContainer, AppColors.primaryDim],
                    ),
                  ),
                  child: Text(
                    'THANH TOÁN  >',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.onPrimaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToCheckout(BuildContext context) async {
    final selectedItems = _controller.items
        .where((item) => _selectedVariantIds.contains(item.variantId))
        .map((item) => CheckoutItem(
              variantId: item.variantId,
              quantity: item.quantity,
              productId: item.productId,
              productName: item.productName,
              variantLabel: item.specText,
              unitPrice: item.price,
              imageUrl: item.imageUrl,
            ))
        .toList();

    if (selectedItems.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          items: selectedItems,
          authController: widget.authController,
          addressController: widget.addressController,
          orderController: widget.orderController,
          onNavigateToHome: widget.onNavigateToHome,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveItem(CartItemModel item) async {

    final approved = await _showDeleteDialog(
      title: 'Xóa sản phẩm',
      message: 'Bạn có chắc muốn xóa "${item.productName}" khỏi giỏ hàng?',
      confirmText: 'Xóa',
    );
    if (approved == true) {
      _controller.remove(item);
    }
  }

  Future<void> _confirmClearCart() async {
    if (_controller.items.isEmpty) {
      return;
    }

    final approved = await _showDeleteDialog(
      title: 'Xóa tất cả sản phẩm',
      message: 'Bạn có chắc muốn xóa toàn bộ sản phẩm trong giỏ hàng?',
      confirmText: 'Xóa hết',
    );
    if (approved == true) {
      _controller.clearCart();
    }
  }

  Future<bool?> _showDeleteDialog({
    required String title,
    required String message,
    required String confirmText,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AppColors.outlineVariant),
          ),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          content: Text(message, style: Theme.of(context).textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(confirmText),
            ),
          ],
        );
      },
    );
  }

  void _syncSelectionWithItems(List<CartItemModel> items) {
    final ids = items.map((e) => e.variantId).toSet();
    _selectedVariantIds.removeWhere((id) => !ids.contains(id));

    if (!_didInitSelection && items.isNotEmpty) {
      _selectedVariantIds
        ..clear()
        ..addAll(ids);
      _didInitSelection = true;
    }
  }

  void _toggleItem(int variantId) {
    setState(() {
      if (_selectedVariantIds.contains(variantId)) {
        _selectedVariantIds.remove(variantId);
      } else {
        _selectedVariantIds.add(variantId);
      }
    });
  }

  void _toggleSelectAll() {
    final ids = _controller.items.map((e) => e.variantId).toSet();
    setState(() {
      if (_selectedVariantIds.length == ids.length) {
        _selectedVariantIds.clear();
      } else {
        _selectedVariantIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  double get _selectedTotal {
    return _controller.items
        .where((item) => _selectedVariantIds.contains(item.variantId))
        .fold<double>(0, (sum, item) => sum + item.lineTotal);
  }

  String _formatPrice(double value) {
    final text = value.toStringAsFixed(0);
    final chars = text.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(chars[i]);
    }
    return '${buffer.toString().split('').reversed.join()}đ';
  }
}

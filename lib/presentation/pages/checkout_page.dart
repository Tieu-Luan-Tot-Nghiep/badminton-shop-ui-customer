import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/checkout_model.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../data/datasources/promotion_remote_data_source.dart';
import '../manager/address_controller.dart';
import '../manager/auth_controller.dart';
import '../manager/order_controller.dart';
import 'address_list_page.dart';
import 'order_history_page.dart';
import 'product_detail_page.dart';

/// A lightweight item DTO passed to CheckoutPage so it works from both
/// CartPage (multiple items) and ProductDetailPage (single item "buy now").
class CheckoutItem {
  const CheckoutItem({
    required this.variantId,
    required this.quantity,
    required this.productId,
    required this.productName,
    required this.variantLabel,
    required this.unitPrice,
    this.imageUrl,
  });

  final int variantId;
  final int quantity;
  final String productId;
  final String productName;
  final String variantLabel;
  final double unitPrice;
  final String? imageUrl;

  double get lineTotal => unitPrice * quantity;
}

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({
    super.key,
    required this.items,
    required this.authController,
    required this.addressController,
    required this.orderController,
    this.onNavigateToHome,
  });

  final List<CheckoutItem> items;
  final AuthController authController;
  final AddressController addressController;
  final OrderController orderController;
  final VoidCallback? onNavigateToHome;

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  static const _codMethod = 'COD';
  static const _vnpayMethod = 'VNPAY';
  static const _callbackScheme = 'shuttlex';

  AddressEntity? _selectedAddress;
  String _paymentMethod = _codMethod;
  final TextEditingController _voucherCtrl = TextEditingController();
  String? _appliedVoucher;
  bool _isPreviewLoading = false;

  // Shipping fee (fixed for COD; will be updated after previewOrder)
  double _shippingFee = 35000;
  double _discount = 0;

  final PromotionRemoteDataSource _promotionRemoteDataSource = PromotionRemoteDataSource();
  List<PromotionEntity> _promotions = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAddresses();
    });
  }

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    await widget.addressController.loadAddresses();
    if (!mounted) return;
    final addresses = widget.addressController.addresses;
    if (addresses.isNotEmpty) {
      setState(() {
        _selectedAddress = addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );
      });
    }
    await _refreshOrderPreview();
    await _loadPromotions();
  }

  Future<void> _loadPromotions() async {
    try {
      final list = await _promotionRemoteDataSource.getActivePromotions();
      if (mounted) {
        setState(() {
          _promotions = list;
        });
      }
    } catch (_) {
      // Ignore
    }
  }

  double get _itemsTotal =>
      widget.items.fold(0, (sum, item) => sum + item.lineTotal);

  double get _total => _itemsTotal + _shippingFee - _discount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.orderController,
                builder: (context, _) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAddressSection(context),
                        const SizedBox(height: 20),
                        _buildOrderSummary(context),
                        const SizedBox(height: 20),
                        _buildVoucherSection(context),
                        const SizedBox(height: 20),
                        _buildPaymentSection(context),
                        const SizedBox(height: 20),
                        _buildPriceSummary(context),
                        const SizedBox(height: 12),
                        _buildPlaceOrderButton(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── TOP BAR ────────────────
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
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
          Text(
            'THANH TOÁN',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── ADDRESS ────────────────
  Widget _buildAddressSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _sectionLabel(context, 'ĐỊA CHỈ GIAO HÀNG'),
            GestureDetector(
              onTap: () => _openAddressPicker(context),
              child: Text(
                'THAY ĐỔI',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _selectedAddress == null
            ? _buildNoAddress(context)
            : _buildAddressCard(context, _selectedAddress!),
      ],
    );
  }

  Widget _buildAddressCard(BuildContext context, AddressEntity address) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: AppColors.primaryContainer, width: 3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2, right: 12),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              color: AppColors.primaryContainer,
              size: 18,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      address.receiverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      address.phoneNumber,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${address.specificAddress}, ${address.ward}, ${address.district}, ${address.province}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoAddress(BuildContext context) {
    return GestureDetector(
      onTap: () => _openAddressPicker(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primaryContainer.withOpacity(0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_location_alt_outlined,
              color: AppColors.primaryContainer,
            ),
            const SizedBox(width: 10),
            Text(
              'Thêm địa chỉ giao hàng',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.primaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── ORDER SUMMARY ────────────────
  Widget _buildOrderSummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'TÓM TẮT ĐƠN HÀNG (${widget.items.length})'),
        const SizedBox(height: 12),
        if (_isPreviewLoading)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: AppColors.outlineVariant),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _buildOrderItemRow(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemRow(BuildContext context, CheckoutItem item) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(
            productId: item.productId,
            authController: widget.authController,
            onNavigateToHome: widget.onNavigateToHome,
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                  ? Image.network(
                      item.imageUrl!,
                      width: 66,
                      height: 66,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (item.variantLabel.isNotEmpty)
                    Text(
                      item.variantLabel,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    _formatPrice(item.unitPrice),
                    style: const TextStyle(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'x${item.quantity}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 66,
    height: 66,
    color: AppColors.surfaceContainerHighest,
    child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
  );

  // ──────────────── VOUCHER ────────────────
  Widget _buildVoucherSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'MÃ GIẢM GIÁ'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                color: AppColors.primaryContainer,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _voucherCtrl,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Nhập mã voucher...',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
              ),
              TextButton(
                onPressed: _isPreviewLoading ? null : _applyVoucher,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryContainer,
                ),
                child: const Text(
                  'ÁP DỤNG',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        if (_appliedVoucher != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Đã áp dụng: $_appliedVoucher',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _removeVoucher,
                child: const Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
        if (_promotions.isNotEmpty && _appliedVoucher == null) ...[
          const SizedBox(height: 14),
          _buildSuggestedVouchers(context),
        ],
      ],
    );
  }

  Widget _buildSuggestedVouchers(BuildContext context) {
    final validPromotions = _promotions.where((promo) => _itemsTotal >= promo.minOrderValue).toList();
    
    if (validPromotions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: validPromotions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final promo = validPromotions[index];
          String discountText;
          if (promo.discountType == 'PERCENTAGE') {
            discountText = 'Giảm ${promo.discountValue.toInt()}%';
          } else if (promo.discountType == 'FREE_SHIP') {
            discountText = 'Miễn phí vận chuyển';
          } else {
            discountText = 'Giảm ${(promo.discountValue / 1000).toInt()}k';
          }
              
          return Container(
            width: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryContainer.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        discountText,
                        style: const TextStyle(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đơn từ ${(promo.minOrderValue / 1000).toInt()}k',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _voucherCtrl.text = promo.code;
                    _applyVoucher();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'DÙNG',
                      style: TextStyle(
                        color: AppColors.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _applyVoucher() async {
    final code = _voucherCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập mã voucher.')),
      );
      return;
    }

    final ok = await _refreshOrderPreview(
      voucherCode: code,
      showErrorOnFail: true,
    );

    if (!mounted || !ok) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã áp dụng voucher ${_appliedVoucher ?? code}.')),
    );
  }

  Future<void> _removeVoucher() async {
    setState(() {
      _appliedVoucher = null;
      _voucherCtrl.clear();
    });
    await _refreshOrderPreview();
  }

  // ──────────────── PAYMENT ────────────────
  Widget _buildPaymentSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(context, 'PHƯƠNG THỨC THANH TOÁN'),
        const SizedBox(height: 12),
        _buildPaymentOption(
          context,
          method: _codMethod,
          icon: Icons.payments_outlined,
          title: 'Thanh toán khi nhận hàng (COD)',
          subtitle: 'Thanh toán bằng tiền mặt khi nhận hàng',
        ),
        const SizedBox(height: 10),
        _buildPaymentOption(
          context,
          method: _vnpayMethod,
          icon: Icons.account_balance_rounded,
          title: 'Ví VNPAY / Ngân hàng',
          subtitle: 'Giảm thêm 20k cho đơn hàng từ 1 triệu',
        ),
      ],
    );
  }

  Widget _buildPaymentOption(
    BuildContext context, {
    required String method,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _paymentMethod == method;
    return GestureDetector(
      onTap: () async {
        setState(() => _paymentMethod = method);
        await _refreshOrderPreview();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryContainer.withOpacity(0.08)
              : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryContainer
                : AppColors.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryContainer.withOpacity(0.15)
                    : AppColors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primaryContainer
                    : AppColors.textSecondary,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryContainer
                      : AppColors.textSecondary,
                  width: 2,
                ),
                color: isSelected
                    ? AppColors.primaryContainer
                    : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: AppColors.onPrimaryContainer,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── PRICE SUMMARY ────────────────
  Widget _buildPriceSummary(BuildContext context) {
    final count = widget.items.fold<int>(0, (sum, e) => sum + e.quantity);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          _buildPriceRow(
            context,
            label: 'Tiền hàng ($count sản phẩm)',
            value: _formatPrice(_itemsTotal),
          ),
          const SizedBox(height: 8),
          _buildPriceRow(
            context,
            label: 'Phí vận chuyển (Giao nhanh)',
            value: _formatPrice(_shippingFee),
          ),
          if (_discount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              context,
              label: '🎫 Giảm giá voucher',
              value: '- ${_formatPrice(_discount)}',
              valueColor: AppColors.primaryContainer,
            ),
          ],
          const Divider(height: 24, color: AppColors.outlineVariant),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TỔNG CỘNG',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              Text(
                _formatPrice(_total),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ──────────────── PLACE ORDER BUTTON ────────────────
  Widget _buildPlaceOrderButton(BuildContext context) {
    final isPlacing = widget.orderController.isPlacing;
    return GestureDetector(
      onTap: isPlacing ? null : () => _placeOrder(context),
      child: AnimatedOpacity(
        opacity: isPlacing ? 0.7 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryContainer, AppColors.primaryDim],
            ),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isPlacing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.onPrimaryContainer,
                  ),
                )
              else
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: AppColors.onPrimaryContainer,
                  size: 22,
                ),
              const SizedBox(width: 10),
              Text(
                isPlacing ? 'ĐANG ĐẶT HÀNG...' : 'ĐẶT HÀNG NGAY',
                style: const TextStyle(
                  color: AppColors.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────── ACTIONS ────────────────
  Future<void> _openAddressPicker(BuildContext context) async {
    final picked = await Navigator.push<AddressEntity>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressListPage(
          controller: widget.addressController,
          authController: widget.authController,
          onNavigateToHome: widget.onNavigateToHome,
          selectionMode: true,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedAddress = picked);
      await _refreshOrderPreview();
    }
  }

  CreateOrderRequest _buildPreviewRequest({String? voucherCode}) {
    return CreateOrderRequest(
      items: widget.items
          .map(
            (e) => CreateOrderItemRequest(
              variantId: e.variantId,
              quantity: e.quantity,
            ),
          )
          .toList(),
      addressId: _selectedAddress?.id,
      voucherCode: voucherCode,
      paymentMethod: _paymentMethod,
    );
  }

  Future<bool> _refreshOrderPreview({
    String? voucherCode,
    bool showErrorOnFail = false,
  }) async {
    if (_isPreviewLoading) {
      return false;
    }

    setState(() => _isPreviewLoading = true);

    try {
      final normalizedVoucher = voucherCode ?? _appliedVoucher;
      final preview = await widget.orderController.previewOrder(
        _buildPreviewRequest(voucherCode: normalizedVoucher),
      );

      if (!mounted) {
        return false;
      }

      if (preview == null) {
        if (showErrorOnFail) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Voucher không hợp lệ')));
        }
        return false;
      }

      setState(() {
        _shippingFee = preview.shippingFee;
        _discount = preview.discountAmount;
        final candidate = (preview.voucherCode ?? normalizedVoucher)?.trim();
        _appliedVoucher = (candidate == null || candidate.isEmpty)
            ? null
            : candidate;
      });

      return true;
    } catch (_) {
      if (mounted && showErrorOnFail) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Voucher không hợp lệ')));
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
      }
    }
  }

  Future<void> _placeOrder(BuildContext context) async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn địa chỉ giao hàng.')),
      );
      return;
    }

    final request = CreateOrderRequest(
      items: widget.items
          .map(
            (e) => CreateOrderItemRequest(
              variantId: e.variantId,
              quantity: e.quantity,
            ),
          )
          .toList(),
      addressId: _selectedAddress!.id,
      voucherCode: _appliedVoucher,
      paymentMethod: _paymentMethod,
      status: _paymentMethod == _vnpayMethod ? 'PENDING' : null,
    );

    final success = await widget.orderController.placeOrder(request);
    if (!context.mounted) return;

    if (success) {
      if (_paymentMethod == _vnpayMethod) {
        final paymentUrl = widget.orderController.lastPlacedOrder?.paymentUrl;
        if (paymentUrl == null || paymentUrl.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không nhận được liên kết thanh toán VNPAY.'),
            ),
          );
          _showSuccessDialog(context);
          return;
        }

        await _startVnpayPayment(paymentUrl);
        return;
      }

      _showSuccessDialog(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.orderController.placeError ?? 'Đặt hàng thất bại.',
          ),
        ),
      );
    }
  }

  Future<void> _startVnpayPayment(String paymentUrl) async {
    try {
      final callbackUrl = await FlutterWebAuth2.authenticate(
        url: paymentUrl,
        callbackUrlScheme: _callbackScheme,
        options: const FlutterWebAuth2Options(preferEphemeral: true),
      );

      if (!mounted) {
        return;
      }

      final result = await widget.orderController
          .completeVnpayPaymentFromCallbackUrl(callbackUrl);

      if (!mounted) {
        return;
      }

      _showVnpayResultDialog(context, result);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showVnpayPendingDialog(context);
    }
  }

  bool _isVnpaySuccess(Map<String, dynamic>? result) {
    if (result == null) {
      return false;
    }

    final paymentStatus = (result['paymentStatus'] ?? '')
        .toString()
        .toUpperCase();
    final responseCode = (result['responseCode'] ?? '').toString();

    return responseCode == '00' ||
        paymentStatus == 'PAID' ||
        paymentStatus == 'SUCCESS';
  }

  void _showVnpayResultDialog(
    BuildContext context,
    Map<String, dynamic>? result,
  ) {
    final success = _isVnpaySuccess(result);
    final responseCode = (result?['responseCode'] ?? '--').toString();
    final paymentStatus = (result?['paymentStatus'] ?? '--').toString();
    final orderCode =
        (result?['orderCode'] ??
                widget.orderController.lastPlacedOrder?.orderCode ??
                '--')
            .toString();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: success
                    ? AppColors.primaryContainer.withOpacity(0.15)
                    : Colors.redAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: success ? AppColors.primaryContainer : Colors.redAccent,
                size: 52,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              success
                  ? 'THANH TOÁN VNPAY THÀNH CÔNG'
                  : 'THANH TOÁN VNPAY CHƯA THÀNH CÔNG',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mã đơn: #$orderCode\nTrạng thái thanh toán: $paymentStatus\nMã phản hồi: $responseCode',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onNavigateToHome != null) {
                widget.onNavigateToHome!();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'VỀ TRANG CHỦ',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => OrderHistoryPage(
                    controller: widget.orderController,
                    authController: widget.authController,
                    onNavigateToHome: widget.onNavigateToHome,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'XEM ĐƠN HÀNG',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  void _showVnpayPendingDialog(BuildContext context) {
    final orderCode = widget.orderController.lastPlacedOrder?.orderCode ?? '--';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'ĐÃ TẠO ĐƠN VNPAY',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
        ),
        content: Text(
          'Đơn #$orderCode đã được tạo. Nếu bạn đã thanh toán nhưng ứng dụng chưa nhận callback, hãy vào Lịch sử đơn hàng để kiểm tra trạng thái mới nhất.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.35),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onNavigateToHome != null) {
                widget.onNavigateToHome!();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('VỀ TRANG CHỦ'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => OrderHistoryPage(
                    controller: widget.orderController,
                    authController: widget.authController,
                    onNavigateToHome: widget.onNavigateToHome,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
            ),
            child: const Text('XEM ĐƠN HÀNG'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryContainer,
                size: 56,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ĐẶT HÀNG THÀNH CÔNG!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Đơn hàng của bạn đã được ghi nhận và đang được xử lý.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (widget.onNavigateToHome != null) {
                widget.onNavigateToHome!();
              } else {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              'VỀ TRANG CHỦ',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => OrderHistoryPage(
                    controller: widget.orderController,
                    authController: widget.authController,
                    onNavigateToHome: widget.onNavigateToHome,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryContainer,
              foregroundColor: AppColors.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'XEM ĐƠN HÀNG',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── HELPERS ────────────────
  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 2,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  String _formatPrice(double value) {
    final text = value.toStringAsFixed(0);
    final chars = text.split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write('.');
      buffer.write(chars[i]);
    }
    return '${buffer.toString().split('').reversed.join()}đ';
  }
}

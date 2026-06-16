import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/shop_remote_data_source.dart';
import '../../domain/entities/product_entity.dart';
import '../manager/address_controller.dart';
import '../manager/auth_controller.dart';
import '../manager/order_controller.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';
import 'checkout_page.dart';
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productId,
    this.initialProduct,
    this.authController,
    this.addressController,
    this.orderController,
    this.cartCountListenable,
    this.chatCountListenable,
    this.onOpenCart,
    this.onOpenChat,
    this.onOpenShopChat,
    this.onRequireLogin,
    this.onCartChanged,
    this.remote,
    this.onNavigateToHome,
  });

  final String productId;
  final ProductEntity? initialProduct;
  final AuthController? authController;
  final AddressController? addressController;
  final OrderController? orderController;
  final ValueListenable<int>? cartCountListenable;
  final ValueListenable<int>? chatCountListenable;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenShopChat;
  final VoidCallback? onRequireLogin;
  final VoidCallback? onCartChanged;
  final ShopRemoteDataSource? remote;
  final VoidCallback? onNavigateToHome;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final ShopRemoteDataSource _remote;
  late Future<_ProductDetailViewData> _future;
  final PageController _pageController = PageController();
  int _currentImage = 0;
  String? _selectedSize;
  String? _selectedColor;

  @override
  void initState() {
    super.initState();
    _remote = widget.remote ?? ShopRemoteDataSource();
    _future = _loadViewData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF04152D), AppColors.surfaceDim],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_ProductDetailViewData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Không thể tải chi tiết sản phẩm',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _future = _loadViewData();
                            });
                          },
                          child: const Text('Thu lai'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final data = snapshot.data!;
              final detail = data.detail;
              final images = detail.images.isEmpty ? const [''] : detail.images;
              final sizes = detail.variants
                  .map((e) => e.size.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();
              final colors = detail.variants
                  .map((e) => e.color.trim())
                  .where((e) => e.isNotEmpty)
                  .toSet()
                  .toList();

              _selectedSize ??= sizes.isNotEmpty ? sizes.first : null;
              _selectedColor ??= colors.isNotEmpty ? colors.first : null;

              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildTopBar(context),
                        const SizedBox(height: 14),
                        _buildImageSlider(images),
                        const SizedBox(height: 16),
                        Text(
                          detail.shortDescription.isEmpty
                              ? 'POWER SERIES'
                              : detail.shortDescription.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.secondary,
                                letterSpacing: 2,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          detail.name.toUpperCase(),
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontSize: 44,
                                fontWeight: FontWeight.w900,
                                fontStyle: FontStyle.italic,
                                height: 0.95,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth:
                                    MediaQuery.of(context).size.width - 120,
                              ),
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatPrice(detail.price),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.primaryContainer,
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                      ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${data.averageRating.toStringAsFixed(1)}/5.0',
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        if (sizes.isNotEmpty) ...[
                          _sectionLabel(context, 'TRỌNG LƯỢNG (WEIGHT)'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: sizes
                                .map(
                                  (size) => ChoiceChip(
                                    selected: size == _selectedSize,
                                    label: Text(size.toUpperCase()),
                                    onSelected: (_) =>
                                        setState(() => _selectedSize = size),
                                    side: BorderSide(
                                      color: size == _selectedSize
                                          ? AppColors.primaryContainer
                                          : AppColors.outlineVariant,
                                    ),
                                    selectedColor: AppColors.primaryContainer,
                                    backgroundColor: AppColors.surfaceContainer,
                                    labelStyle: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: size == _selectedSize
                                              ? AppColors.onPrimaryContainer
                                              : AppColors.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (colors.isNotEmpty) ...[
                          _sectionLabel(context, 'MÀU SẮC (PHIÊN BẢN)'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 14,
                            runSpacing: 10,
                            children: colors
                                .map(
                                  (colorName) => GestureDetector(
                                    onTap: () => setState(
                                      () => _selectedColor = colorName,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 42,
                                          height: 42,
                                          padding: const EdgeInsets.all(3),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: colorName == _selectedColor
                                                  ? AppColors.primaryContainer
                                                  : AppColors.outlineVariant,
                                              width: 2,
                                            ),
                                          ),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _toColor(colorName),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          colorName.toUpperCase(),
                                          style: Theme.of(
                                            context,
                                          ).textTheme.labelSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 18),
                        ],
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(26),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CÔNG NGHỆ ĐỘT PHÁ',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: AppColors.secondary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                detail.description.isEmpty
                                    ? 'Sản phẩm được thiết kế để tối ưu sức mạnh và độ linh hoạt cho người chơi cầu lông chuyên nghiệp.'
                                    : detail.description,
                                style: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.copyWith(height: 1.45),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Text(
                              'ĐÁNH GIÁ (${data.totalReviews})',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              'XEM TẤT CẢ',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (data.reviews.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              'Chưa có đánh giá cho sản phẩm này.',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          )
                        else
                          ...data.reviews.map(
                            (review) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _buildReviewCard(context, review),
                            ),
                          ),
                        // ── Sản phẩm gợi ý ──────────────────────────────
                        if (data.recommendations != null &&
                            data.recommendations!.recommendations.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          _buildRecommendationsSection(
                              context, data.recommendations!),
                        ],
                      ],
                    ),
                  ),
                  _buildBottomBar(context, detail),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<_ProductDetailViewData> _loadViewData() async {
    final detail = await _remote.getProductDetail(widget.productId);

    ShopProductReviewSummaryModel? summary;
    try {
      summary = await _remote.getProductReviewSummary(
        productId: widget.productId,
      );
    } catch (_) {
      summary = null;
    }

    List<ShopProductReviewModel> reviews;
    try {
      reviews = await _remote.getProductReviews(productId: widget.productId);
    } catch (_) {
      reviews = const [];
    }

    ShopProductRecommendationsModel? recommendations;
    try {
      recommendations = await _remote.getProductRecommendations(
        productId: widget.productId,
        size: 6,
      );
    } catch (_) {
      recommendations = null;
    }

    return _ProductDetailViewData(
      detail: detail,
      reviews: reviews,
      summary: summary,
      recommendations: recommendations,
    );
  }

  Widget _buildReviewCard(BuildContext context, ShopProductReviewModel review) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.username.toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${review.rating.toStringAsFixed(1)}/5.0',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(review.comment, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(
    BuildContext context,
    ShopProductRecommendationsModel data,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'CÓ THỂ BẠN CŨNG THÍCH',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ),
          ],
        ),
        // AI insight nếu có
        if (data.aiInsightEnabled &&
            data.aiInsight != null &&
            data.aiInsight!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.primaryContainer,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.aiInsight!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        // Danh sách sản phẩm gợi ý
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: data.recommendations.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = data.recommendations[index];
              return _buildRecommendationCard(context, item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard(
    BuildContext context,
    ShopProductRecommendationItemModel item,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              productId: '${item.id}',
              authController: widget.authController,
              addressController: widget.addressController,
              orderController: widget.orderController,
              cartCountListenable: widget.cartCountListenable,
              chatCountListenable: widget.chatCountListenable,
              onOpenCart: widget.onOpenCart,
              onOpenChat: widget.onOpenChat,
              onOpenShopChat: widget.onOpenShopChat,
              onRequireLogin: widget.onRequireLogin,
              onCartChanged: widget.onCartChanged,
              onNavigateToHome: widget.onNavigateToHome,
            ),
          ),
        );
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ảnh sản phẩm
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: AspectRatio(
                aspectRatio: 1.1,
                child: item.thumbnailUrl != null &&
                        item.thumbnailUrl!.isNotEmpty
                    ? Image.network(
                        item.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined,
                              color: AppColors.textSecondary),
                        ),
                      )
                    : Container(
                        color: AppColors.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textSecondary),
                      ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand tag
                    if (item.brandName.isNotEmpty)
                      Text(
                        item.brandName.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.secondary,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                      ),
                    const SizedBox(height: 2),
                    // Tên sản phẩm
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1.2,
                          ),
                    ),
                    const Spacer(),
                    // Giá
                    Text(
                      _formatPrice(item.basePrice),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        Flexible(
          child: GestureDetector(
            onTap: widget.onNavigateToHome,
            child: Text(
              'SHUTTLE_X',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.primaryContainer,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      const SizedBox(width: 6),
      // Chat với chủ shop (real-time) — badge hiển thị tin nhắn chưa đọc
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
      // Chatbot AI — không có badge
      ChatIconBubble(count: 0, onTap: widget.onOpenChat),
      const SizedBox(width: 6),
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
          backgroundImage: widget.authController?.userProfile?.avatar != null
              ? NetworkImage(widget.authController!.userProfile!.avatar!)
              : null,
          child: widget.authController?.userProfile?.avatar == null
              ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20)
              : null,
        ),
      ],
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return Column(
      children: [
        SizedBox(
          height: 330,
          child: PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (index) {
              setState(() => _currentImage = index);
            },
            itemBuilder: (context, index) {
              final url = images[index];
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: url.isEmpty
                    ? Container(
                        color: AppColors.surfaceContainer,
                        child: const Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      )
                    : Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainer,
                          child: const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            images.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _currentImage == index ? 26 : 8,
              height: 6,
              decoration: BoxDecoration(
                color: _currentImage == index
                    ? AppColors.primaryContainer
                    : AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, ShopProductDetailModel detail) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.9),
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _addToCart(detail: detail, goToCart: false),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryContainer,
                side: const BorderSide(color: AppColors.primaryContainer),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('THÊM GIỎ HÀNG'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () => _buyNow(detail: detail),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryContainer,
                foregroundColor: AppColors.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('MUA NGAY'),
            ),
          ),
        ],
      ),
    );
  }

  void _buyNow({required ShopProductDetailModel detail}) {
    final auth = widget.authController;
    if (auth == null || !auth.isAuthenticated) {
      widget.onRequireLogin?.call();
      return;
    }

    final variantId = _resolveVariantId(detail);
    if (variantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sản phẩm chưa có phiên bản để mua.')),
      );
      return;
    }

    final variant = detail.variants.firstWhere(
      (v) => v.id == variantId,
      orElse: () => detail.variants.first,
    );

    final label = [
      if (variant.color.isNotEmpty) variant.color.toUpperCase(),
      if (variant.size.isNotEmpty) variant.size.toUpperCase(),
    ].join(' | ');

    final addrCtrl = widget.addressController;
    final orderCtrl = widget.orderController;

    if (addrCtrl == null || orderCtrl == null) {
      // Fallback: add to cart and open it
      _addToCart(detail: detail, goToCart: true);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutPage(
          items: [
            CheckoutItem(
              variantId: variantId,
              quantity: 1,
              productId: detail.id,
              productName: detail.name,
              variantLabel: label,
              unitPrice: variant.price > 0 ? variant.price : detail.price,
              imageUrl: detail.images.isNotEmpty ? detail.images.first : null,
            ),
          ],
          authController: auth,
          addressController: addrCtrl,
          orderController: orderCtrl,
          onNavigateToHome: widget.onNavigateToHome,
        ),
      ),
    );
  }

  Future<void> _addToCart({
    required ShopProductDetailModel detail,
    required bool goToCart,
  }) async {
    final auth = widget.authController;
    if (auth == null || !auth.isAuthenticated) {
      widget.onRequireLogin?.call();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng đăng nhập để thêm vào giỏ hàng.'),
        ),
      );
      return;
    }

    final variantId = _resolveVariantId(detail);
    if (variantId == null) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('San pham chua co phien ban de dat mua.')),
      );
      return;
    }

    try {
      await _remote.addToCart(
        variantId: variantId,
        quantity: 1,
        accessToken: auth.session?.token,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm sản phẩm vào giỏ hàng.')),
      );
      widget.onCartChanged?.call();

      if (goToCart && widget.onOpenCart != null) {
        Navigator.of(context).pop();
        widget.onOpenCart!.call();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Khong the them vao gio hang. Vui long thu lai.'),
        ),
      );
    }
  }

  int? _resolveVariantId(ShopProductDetailModel detail) {
    if (detail.variants.isEmpty) {
      return null;
    }

    ShopProductVariantModel? best;

    for (final variant in detail.variants) {
      final sizeMatch =
          _selectedSize == null ||
          variant.size.trim().toLowerCase() ==
              _selectedSize!.trim().toLowerCase();
      final colorMatch =
          _selectedColor == null ||
          variant.color.trim().toLowerCase() ==
              _selectedColor!.trim().toLowerCase();

      if (sizeMatch && colorMatch) {
        if (variant.stock > 0) {
          return variant.id;
        }
        best ??= variant;
      }
    }

    if (best != null) {
      return best.id;
    }

    for (final variant in detail.variants) {
      if (variant.stock > 0) {
        return variant.id;
      }
    }

    return detail.variants.first.id;
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.textSecondary,
        letterSpacing: 2,
      ),
    );
  }

  Color _toColor(String input) {
    final value = input.toLowerCase();
    if (value.contains('white') || value.contains('trang')) {
      return Colors.white;
    }
    if (value.contains('black') || value.contains('den')) {
      return const Color(0xFF121212);
    }
    if (value.contains('blue') || value.contains('xanh')) {
      return const Color(0xFF1B67D2);
    }
    if (value.contains('red') || value.contains('do')) {
      return const Color(0xFFD53737);
    }
    if (value.contains('yellow') || value.contains('vang')) {
      return const Color(0xFFF4CC32);
    }
    return AppColors.surfaceContainerHighest;
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
    return '${buffer.toString().split('').reversed.join()} VND';
  }
}

class _ProductDetailViewData {
  const _ProductDetailViewData({
    required this.detail,
    required this.reviews,
    required this.summary,
    this.recommendations,
  });

  final ShopProductDetailModel detail;
  final List<ShopProductReviewModel> reviews;
  final ShopProductReviewSummaryModel? summary;
  final ShopProductRecommendationsModel? recommendations;

  double get averageRating {
    final value = summary?.averageRating ?? detail.rating;
    if (value <= 0 && reviews.isNotEmpty) {
      final total = reviews.fold<double>(0, (sum, e) => sum + e.rating);
      return total / reviews.length;
    }
    return value > 0 ? value : 5;
  }

  int get totalReviews {
    final value = summary?.totalReviews ?? reviews.length;
    return value < 0 ? 0 : value;
  }
}

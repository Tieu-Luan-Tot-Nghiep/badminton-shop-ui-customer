import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/home_local_data_source.dart';
import '../../data/datasources/home_remote_data_source.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/promotion_entity.dart';
import '../../domain/usecases/get_home_data_usecase.dart';
import '../manager/auth_controller.dart';
import '../manager/home_controller.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';
import '../widgets/category_chip.dart';
import '../widgets/product_card.dart';
import 'membership_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.controller,
    this.cartCountListenable,
    this.chatCountListenable,
    this.onOpenCart,
    this.onOpenChat,
    this.onCategorySelected,
    this.onProductSelected,
    this.onSearchSubmitted,
    this.onNavigateToHome,
    required this.authController,
  });

  final HomeController? controller;
  final AuthController authController;
  final ValueListenable<int>? cartCountListenable;
  final ValueListenable<int>? chatCountListenable;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final ValueChanged<CategoryEntity>? onCategorySelected;
  final ValueChanged<ProductEntity>? onProductSelected;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onNavigateToHome;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HomeController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
      if (_controller.feed == null && !_controller.isSyncing) {
        _controller.load();
      }
      return;
    }

    final remote = HomeRemoteDataSource();
    final local = HomeLocalDataSource();
    final repo = HomeRepositoryImpl(remote, local);
    final useCase = GetHomeDataUseCase(repo);
    _controller = HomeController(useCase)..load();
    _ownsController = true;
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        if (_controller.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Không tải được dữ liệu Home',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _controller.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _controller.load,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        final feed = _controller.feed;
        if (feed == null) {
          return const SizedBox.shrink();
        }

        return RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _controller.load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _buildTopBar(context),
              const SizedBox(height: 18),
              _buildSearchBar(),
              if (_controller.isSyncing || _controller.syncWarning != null) ...[
                const SizedBox(height: 10),
                _buildSyncStatus(context),
              ],
              const SizedBox(height: 20),
              _buildPromoCard(context),
              const SizedBox(height: 26),
              _buildBrandShowcase(context),
              const SizedBox(height: 26),
              _buildSectionHeader(context, 'DANH MỤC', 'Xem tất cả'),
              const SizedBox(height: 14),
              _buildCategories(feed.categories),
              const SizedBox(height: 28),
              _buildFlashSale(context),
              const SizedBox(height: 28),
              _buildSectionHeader(context, 'SẢN PHẨM NỔI BẬT', 'Xem thêm'),
              const SizedBox(height: 14),
              _buildProducts(feed.featuredProducts, badge: 'PRO'),
              const SizedBox(height: 30),
              _buildMembershipBanner(context),
              const SizedBox(height: 30),
              _buildSectionHeader(context, 'HÀNG MỚI VỀ', 'Làm mới'),
              const SizedBox(height: 14),
              _buildProducts(feed.newestProducts, badge: 'NEW'),
              if (_controller.promotions.isNotEmpty) ...[
                const SizedBox(height: 30),
                _buildSectionHeader(context, 'GIẢM GIÁ', 'Lấy mã'),
                const SizedBox(height: 14),
                _buildPromotionsList(_controller.promotions),
              ],
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
              return ChatIconBubble(count: count, onTap: widget.onOpenChat);
            },
          )
        else
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

  Widget _buildSearchBar() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(29),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onSubmitted: (value) {
                if (value.trim().isNotEmpty &&
                    widget.onSearchSubmitted != null) {
                  widget.onSearchSubmitted!(value.trim());
                }
              },
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tìm kiếm vợt, giày, phụ kiện...',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          const Icon(
            Icons.keyboard_voice_outlined,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildPromoCard(BuildContext context) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.tertiary,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              'PRO SERIES',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.surfaceDim),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'GIẢM ĐẾN 30%\nYONEX ASTROX',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                bottomLeft: Radius.circular(10),
                topRight: Radius.circular(100),
                bottomRight: Radius.circular(100),
              ),
              gradient: LinearGradient(
                colors: [AppColors.primaryContainer, AppColors.primaryDim],
              ),
            ),
            child: Text(
              'MUA NGAY  →',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.onPrimaryContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context) {
    final isWarning = _controller.syncWarning != null;
    final text =
        _controller.syncWarning ?? 'Đang đồng bộ dữ liệu mới từ máy chủ...';
    final icon = isWarning ? Icons.wifi_off_rounded : Icons.sync_rounded;
    final color = isWarning ? AppColors.tertiary : AppColors.secondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
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
        Text(
          action,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.primaryContainer),
        ),
      ],
    );
  }

  Widget _buildCategories(List<CategoryEntity> categories) {
    final fallback = const ['Vợt', 'Giày', 'Áo', 'Phụ kiện'];
    final data = categories.isEmpty
        ? fallback
              .map((e) => CategoryEntity(id: e, name: e, slug: e.toLowerCase()))
              .toList()
        : categories;

    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = data[index];
          return CategoryChip(
            label: item.name,
            iconAsset: _categoryIconAsset(item),
            onTap: () {
              if (widget.onCategorySelected != null) {
                widget.onCategorySelected!(item);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildProducts(List<ProductEntity> products, {String? badge}) {
    if (products.isEmpty) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('Chưa có sản phẩm')),
      );
    }

    return SizedBox(
      height: 300,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return ProductCard(
            product: product,
            badge: badge,
            onTap: () {
              if (widget.onProductSelected != null) {
                widget.onProductSelected!(product);
              }
            },
          );
        },
      ),
    );
  }

  String _categoryIconAsset(CategoryEntity category) {
    final slug = category.slug.toLowerCase();
    final name = category.name.toLowerCase();

    // Tất cả sản phẩm
    if (slug == 'all' || name.contains('tất cả') || name.contains('tat ca')) {
      return 'assets/icons/categories/all.svg';
    }

    // Vợt cầu lông
    if (slug.contains('vot') ||
        slug.contains('racket') ||
        name.contains('vợt cầu lông') ||
        name.contains('vot cau long') ||
        name.contains('vợt')) {
      return 'assets/icons/categories/vot.svg';
    }

    // Giày cầu lông
    if (slug.contains('shoe') ||
        slug.contains('giay') ||
        name.contains('giày cầu lông') ||
        name.contains('giay cau long') ||
        name.contains('giày')) {
      return 'assets/icons/categories/giay.svg';
    }

    // Túi và bao vợt (ưu tiên trước balo)
    if (slug.contains('tui') ||
        slug.contains('bag') ||
        name.contains('túi & bao vợt') ||
        name.contains('túi & bao vợt') ||
        name.contains('túi') ||
        name.contains('bao vợt') ||
        name.contains('bao') ||
        slug.contains('case')) {
      return 'assets/icons/categories/tui_bao_vot.svg';
    }

    // Ba lô cầu lông
    if (slug.contains('balo') ||
        slug.contains('backpack') ||
        name.contains('ba lô cầu lông') ||
        name.contains('ba lo cau long') ||
        name.contains('ba lô') ||
        name.contains('balo')) {
      return 'assets/icons/categories/balo.svg';
    }

    // Quả cầu lông (shuttlecock) - ưu tiên trước "cầu" chung
    if (name.contains('quả cầu lông') ||
        name.contains('qua cau long') ||
        name.contains('quả cầu') ||
        name.contains('qua cau') ||
        slug.contains('shuttle') ||
        name.contains('shuttlecock') ||
        name.contains('quả') ||
        slug.contains('ball')) {
      return 'assets/icons/categories/cau_long.svg';
    }

    // Cầu lông chung (nếu không phải quả cầu)
    if (slug.contains('cau') || name.contains('cầu')) {
      return 'assets/icons/categories/cau_long.svg';
    }

    // Phụ kiện cầu lông
    if (slug.contains('access') ||
        slug.contains('phu-kien') ||
        name.contains('phụ kiện cầu lông') ||
        name.contains('phu kien cau long') ||
        name.contains('phụ kiện') ||
        slug.contains('grip') ||
        name.contains('grip') ||
        slug.contains('overgrip') ||
        name.contains('băng quấn') ||
        name.contains('bang quan') ||
        name.contains('dây đeo') ||
        name.contains('day deo')) {
      return 'assets/icons/categories/phu_kien.svg';
    }

    // Quần áo cầu lông
    if (slug.contains('shirt') ||
        slug.contains('ao') ||
        name.contains('quần áo cầu lông') ||
        name.contains('quan ao cau long') ||
        name.contains('áo') ||
        slug.contains('jersey') ||
        name.contains('jersey')) {
      return 'assets/icons/categories/ao.svg';
    }

    // Quần thể thao
    if (slug.contains('quan') ||
        slug.contains('short') ||
        name.contains('quần') ||
        name.contains('short')) {
      return 'assets/icons/categories/ao.svg';
    }

    // Cước vợt (strings)
    if (slug.contains('cuoc') ||
        slug.contains('string') ||
        name.contains('cước') ||
        name.contains('dây vợt') ||
        name.contains('day vot')) {
      return 'assets/icons/categories/phu_kien.svg';
    }

    // Khác
    if (slug.contains('khac') ||
        name.contains('khác') ||
        slug.contains('other')) {
      return 'assets/icons/categories/all.svg';
    }

    // Mặc định
    return 'assets/icons/categories/all.svg';
  }

  Widget _buildPromotionsList(List<PromotionEntity> promotions) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: promotions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final promo = promotions[index];
          String discountText;
          if (promo.discountType == 'PERCENTAGE') {
            discountText = 'Giảm ${promo.discountValue.toInt()}%';
          } else if (promo.discountType == 'FREE_SHIP') {
            discountText = 'Miễn phí vận chuyển';
          } else {
            discountText = 'Giảm ${(promo.discountValue / 1000).toInt()}k';
          }
          return Container(
            width: 240,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
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
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Mã: ${promo.code}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đơn tối thiểu ${(promo.minOrderValue / 1000).toInt()}k',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBrandShowcase(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'THƯƠNG HIỆU',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'YONEX • VICTOR\nLI-NING • MIZUNO',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: const Icon(
                Icons.sports_tennis_rounded,
                size: 48,
                color: Colors.white38,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlashSale(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8E53)],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.flash_on_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FLASH SALE',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Giảm đến 50% - Chỉ hôm nay!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'MUA NGAY',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFFFF6B35),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembershipBanner(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MembershipPage(
              authController: widget.authController,
              onNavigateToHome: widget.onNavigateToHome,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'VIP MEMBER',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'THAM GIA NGAY\nĐỂ NHẬN ƯU ĐÃI',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Miễn phí ship • Giảm giá VIP • Tích điểm',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.card_membership_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

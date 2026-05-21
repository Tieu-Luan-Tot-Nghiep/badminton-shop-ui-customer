import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';
import '../../data/datasources/shop_local_data_source.dart';
import '../../data/datasources/shop_remote_data_source.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../manager/address_controller.dart';
import '../manager/auth_controller.dart';
import '../manager/order_controller.dart';
import '../manager/shop_controller.dart';
import '../models/scan_search_payload.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';
import 'product_detail_page.dart';

class ShopPage extends StatefulWidget {
  const ShopPage({
    super.key,
    required this.authController,
    required this.cartCountListenable,
    this.chatCountListenable,
    this.scanSearchResultListenable,
    this.categorySlugListenable,
    this.searchKeywordListenable,
    this.addressController,
    this.orderController,
    this.onOpenCart,
    this.onOpenChat,
    this.onNavigateToHome,
    this.onCartChanged,
    this.onRequireLogin,
  });

  final AuthController authController;
  final ValueListenable<int> cartCountListenable;
  final ValueListenable<int>? chatCountListenable;
  final ValueListenable<ScanSearchPayload?>? scanSearchResultListenable;
  final ValueListenable<String?>? categorySlugListenable;
  final ValueListenable<String?>? searchKeywordListenable;
  final AddressController? addressController;
  final OrderController? orderController;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final VoidCallback? onNavigateToHome;
  final VoidCallback? onCartChanged;
  final VoidCallback? onRequireLogin;

  @override
  State<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends State<ShopPage> {
  late final ShopController _controller;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _categoryScrollController = ScrollController();
  ScanSearchPayload? _lastAppliedScanPayload;

  @override
  void initState() {
    super.initState();
    _controller = ShopController(ShopRemoteDataSource(), ShopLocalDataSource());

    final initialSlug = widget.categorySlugListenable?.value;
    if (initialSlug != null && initialSlug.isNotEmpty) {
      _controller.selectedCategorySlug = initialSlug;
    }

    final initialKeyword = widget.searchKeywordListenable?.value;
    if (initialKeyword != null && initialKeyword.isNotEmpty) {
      _controller.keyword = initialKeyword;
      _searchController.text = initialKeyword;
    }

    _controller.loadInitial();
    
    _scrollController.addListener(_onScroll);
    widget.scanSearchResultListenable?.addListener(_onScanResultChanged);
    widget.categorySlugListenable?.addListener(_onCategorySlugChanged);
    widget.searchKeywordListenable?.addListener(_onSearchKeywordChanged);
  }

  void _onCategorySlugChanged() {
    final slug = widget.categorySlugListenable?.value;
    if (slug != null && slug.isNotEmpty && _controller.selectedCategorySlug != slug) {
      _controller.selectCategory(slug);
    }
  }

  void _onSearchKeywordChanged() {
    final keyword = widget.searchKeywordListenable?.value;
    if (keyword != null && keyword.isNotEmpty && _controller.keyword != keyword) {
      _searchController.text = keyword;
      _controller.applySearch(forceKeyword: keyword);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _categoryScrollController.dispose();
    widget.scanSearchResultListenable?.removeListener(_onScanResultChanged);
    widget.categorySlugListenable?.removeListener(_onCategorySlugChanged);
    widget.searchKeywordListenable?.removeListener(_onSearchKeywordChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onScanResultChanged() {
    final payload = widget.scanSearchResultListenable?.value;
    if (payload == null || identical(payload, _lastAppliedScanPayload)) {
      return;
    }

    _lastAppliedScanPayload = payload;
    _searchController.clear();
    _controller.applyScanResults(payload.products);

    final message = payload.products.isEmpty
        ? 'Không tìm thấy sản phẩm phù hợp từ hình ảnh đã chọn.'
        : 'Đã cập nhật kết quả tìm kiếm bằng hình ảnh.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _onScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final threshold = _scrollController.position.maxScrollExtent - 220;
    if (_scrollController.offset >= threshold) {
      _controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        if (_controller.isLoading && _controller.products.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        if (_controller.error != null && _controller.products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _controller.error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _controller.loadInitial,
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          color: AppColors.secondary,
          onRefresh: _controller.refresh,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _buildTopBar(context),
              const SizedBox(height: 18),
              _buildSearchBar(context),
              if (_controller.suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSuggestions(context),
              ],
              if (_controller.syncWarning != null) ...[
                const SizedBox(height: 10),
                _buildSyncStatus(context),
              ],
              const SizedBox(height: 20),
              _buildSectionHeader(context, 'DANH MỤC SẢN PHẨM', 'Xem tất cả'),
              const SizedBox(height: 12),
              _buildCategories(context),
              const SizedBox(height: 22),
              _buildSectionHeader(context, 'KẾT QUẢ', 'Lọc & Sắp xếp'),
              const SizedBox(height: 10),
              _buildResultHeader(context),
              const SizedBox(height: 14),
              _buildProductGrid(context),
              if (_controller.isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondary,
                      strokeWidth: 2,
                    ),
                  ),
                ),
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
        ValueListenableBuilder<int>(
          valueListenable: widget.cartCountListenable,
          builder: (_, count, __) {
            return CartIconBubble(count: count, onTap: widget.onOpenCart);
          },
        ),
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



  Widget _buildSearchBar(BuildContext context) {
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
              controller: _searchController,
              onChanged: _controller.onKeywordChanged,
              onSubmitted: (_) => _controller.applySearch(),
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Tìm kiếm trang bị chuyên nghiệp',
                hintStyle: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
          IconButton(
            onPressed: _showFilterSort,
            icon: const Icon(
              Icons.tune_rounded,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncStatus(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 16,
            color: AppColors.tertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _controller.syncWarning ?? '',
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
          ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: _controller.suggestions
            .map(
              (s) => ListTile(
                dense: true,
                title: Text(s, style: Theme.of(context).textTheme.bodyMedium),
                onTap: () {
                  _searchController.text = s;
                  _controller.applySearch(forceKeyword: s);
                },
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCategories(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView.separated(
        controller: _categoryScrollController,
        scrollDirection: Axis.horizontal,
        itemCount: _controller.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = _controller.categories[index];
          final selected = item.slug == _controller.selectedCategorySlug;
          final iconAsset = _categoryIconAsset(item);

          final labelColor = selected
              ? AppColors.onPrimaryContainer
              : AppColors.textPrimary;

          return ChoiceChip(
            selected: selected,
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(labelColor, BlendMode.srcIn),
                ),
                const SizedBox(width: 6),
                Text(_getCategoryDisplayName(item).toUpperCase()),
              ],
            ),
            onSelected: (_) {
              _controller.selectCategory(item.slug);
              _scrollCategoryToCenter(index);
            },
            backgroundColor: AppColors.surfaceContainer,
            selectedColor: AppColors.primaryContainer,
            labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          );
        },
      ),
    );
  }

  String _getCategoryDisplayName(CategoryEntity category) {
    if (category.slug == 'all' || category.name.toLowerCase().contains('tat ca')) {
      return 'Tất cả';
    }
    return category.name;
  }

  void _scrollCategoryToCenter(int index) {
    // Tính toán vị trí để scroll category được chọn về giữa
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = 120.0; // Ước tính width của mỗi category chip
    final spacing = 10.0;
    final totalItemWidth = itemWidth + spacing;
    final centerOffset = (screenWidth / 2) - (itemWidth / 2);
    final targetOffset = (index * totalItemWidth) - centerOffset;
    
    // Scroll với animation mượt
    if (_categoryScrollController.hasClients) {
      _categoryScrollController.animateTo(
        targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
        name.contains('tui & bao vot') ||
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
    if (slug.contains('quan') || slug.contains('short') || name.contains('quần') || 
        name.contains('short')) {
      return 'assets/icons/categories/ao.svg';
    }
    
    // Cước vợt (strings)
    if (slug.contains('cuoc') || slug.contains('string') || name.contains('cước') ||
        name.contains('dây vợt') || name.contains('day vot')) {
      return 'assets/icons/categories/phu_kien.svg';
    }
    
    // Khác
    if (slug.contains('khac') || name.contains('khác') || slug.contains('other')) {
      return 'assets/icons/categories/all.svg';
    }
    
    // Mặc định
    return 'assets/icons/categories/all.svg';
  }

  Widget _buildResultHeader(BuildContext context) {
    return Row(
      children: [
        Text(
          '${_controller.products.length}',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            color: AppColors.secondary,
            fontSize: 46,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'KẾT QUẢ ĐƯỢC TÌM THẤY',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showFilterSort,
          style: OutlinedButton.styleFrom(
            side: BorderSide.none,
            backgroundColor: AppColors.surfaceContainerHighest,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: Text(
            _controller.isScanResultMode ? 'KẾT QUẢ SCAN' : 'LỌC & SẮP XẾP',
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(BuildContext context) {
    if (_controller.products.isEmpty) {
      return Container(
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Center(child: Text('Không có sản phẩm phù hợp')),
      );
    }

    return GridView.builder(
      itemCount: _controller.products.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.56,
      ),
      itemBuilder: (context, index) {
        final product = _controller.products[index];
        return _ShopProductCard(
          product: product,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProductDetailPage(
                  productId: product.id,
                  initialProduct: product,
                  authController: widget.authController,
                  addressController: widget.addressController,
                  orderController: widget.orderController,
                  cartCountListenable: widget.cartCountListenable,
                  onOpenCart: widget.onOpenCart,
                  onRequireLogin: widget.onRequireLogin,
                  onCartChanged: widget.onCartChanged,
                  onNavigateToHome: widget.onNavigateToHome,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showFilterSort() async {
    String selectedBy = _controller.sortBy;
    String selectedDir = _controller.sortDir;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sắp xếp', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedBy,
                  items: const [
                    DropdownMenuItem(
                      value: 'createdAt',
                      child: Text('Mới nhất'),
                    ),
                    DropdownMenuItem(value: 'basePrice', child: Text('Giá')),
                    DropdownMenuItem(value: 'name', child: Text('Tên')),
                  ],
                  onChanged: (v) {
                    if (v == null) {
                      return;
                    }
                    setModalState(() => selectedBy = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedDir,
                  items: const [
                    DropdownMenuItem(value: 'desc', child: Text('Giảm dần')),
                    DropdownMenuItem(value: 'asc', child: Text('Tăng dần')),
                  ],
                  onChanged: (v) {
                    if (v == null) {
                      return;
                    }
                    setModalState(() => selectedDir = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _controller.setSort(by: selectedBy, dir: selectedDir);
                    },
                    child: const Text('ÁP DỤNG'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ShopProductCard extends StatelessWidget {
  const _ShopProductCard({required this.product, required this.onTap});

  final ProductEntity product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final oldPrice = product.price * 1.1;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 1.12,
                child: product.imageUrl == null || product.imageUrl!.isEmpty
                    ? Container(
                        color: AppColors.surfaceContainerHighest,
                        child: const Icon(Icons.image_not_supported_outlined),
                      )
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceContainerHighest,
                          child: const Icon(Icons.broken_image_outlined),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              product.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              _formatPrice(oldPrice),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const Spacer(),
            Text(
              _formatPrice(product.price),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
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
    return '${buffer.toString().split('').reversed.join()}d';
  }
}

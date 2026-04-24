import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../datasources/admin_master_data_local_data_source.dart';
import '../datasources/admin_products_local_data_source.dart';
import 'admin_product_detail_page.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';

class AdminProductsPage extends StatefulWidget {
  const AdminProductsPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<AdminProductsPage> {
  static const List<String> _statusFilters = <String>[
    'ALL',
    'ACTIVE',
    'INACTIVE',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String? _selectedCategory;
  String? _selectedBrand;
  int _currentPage = 0;
  final int _pageSize = 20;
  int _totalPages = 1;
  int _totalElements = 0;
  final Set<String> _togglingProductIds = <String>{};
  final Map<String, bool> _activeOverrides = <String, bool>{};

  List<Map<String, dynamic>> _brands = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = const <Map<String, dynamic>>[];
  final AdminMasterDataLocalDataSource _localMasterData =
      AdminMasterDataLocalDataSource();
  final AdminProductsLocalDataSource _localProducts =
      AdminProductsLocalDataSource();

  late Future<AdminPageResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadMasterData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final cachedBrands = await _localMasterData.getCachedBrands();
      final cachedCategories = await _localMasterData.getCachedCategories();
      if (mounted && (cachedBrands.isNotEmpty || cachedCategories.isNotEmpty)) {
        setState(() {
          if (cachedBrands.isNotEmpty) {
            _brands = cachedBrands;
          }
          if (cachedCategories.isNotEmpty) {
            _categories = cachedCategories;
          }
        });
      }

      if (cachedBrands.isNotEmpty && cachedCategories.isNotEmpty) {
        return;
      }
    } catch (_) {
      // Ignore cache read failures and continue with remote source.
    }

    try {
      final brands = await widget.dataSource.getBrands(token);
      final categories = await widget.dataSource.getCategories(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _brands = brands;
        _categories = categories;
      });

      await _localMasterData.cacheBrands(brands);
      await _localMasterData.cacheCategories(categories);
    } catch (_) {
      // Keep page usable when filters cannot be fetched.
    }
  }

  Future<AdminPageResult> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final keyword = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    final isActiveFilter = _selectedStatus == 'ALL'
        ? null
        : _selectedStatus == 'ACTIVE';
    final cacheKey = _productsCacheKey(
      page: _currentPage,
      size: _pageSize,
      keyword: keyword,
      category: _selectedCategory,
      brand: _selectedBrand,
      isActive: isActiveFilter,
      isDeleted: false,
    );

    try {
      final result = await widget.dataSource.getProductsAdmin(
        token,
        page: _currentPage,
        size: _pageSize,
        keyword: keyword,
        category: _selectedCategory,
        brand: _selectedBrand,
        isActive: isActiveFilter,
        isDeleted: false,
      );

      await _localProducts.cacheProducts(cacheKey, result);

      _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
      _totalElements = result.totalElements;
      return result;
    } on DioException catch (e) {
      final serverMsg = e.response?.data?.toString() ?? e.message;
      final fullError = 'Lỗi Server (HTTP ${e.response?.statusCode}): $serverMsg';
      debugPrint('>>> ADMIN SEARCH ERROR: $fullError');
      final cached = await _localProducts.getCachedProducts(cacheKey);
      if (cached != null) {
        _totalPages = cached.totalPages <= 0 ? 1 : cached.totalPages;
        _totalElements = cached.totalElements;
        return cached;
      }

      throw Exception(fullError);
    } catch (e) {
      debugPrint('>>> ADMIN SEARCH ERROR UNKNOWN: $e');
      final cached = await _localProducts.getCachedProducts(cacheKey);
      if (cached != null) {
        _totalPages = cached.totalPages <= 0 ? 1 : cached.totalPages;
        _totalElements = cached.totalElements;
        return cached;
      }
      rethrow;
    }
  }

  String _productsCacheKey({
    required int page,
    required int size,
    required String? keyword,
    required String? category,
    required String? brand,
    required bool? isActive,
    required bool isDeleted,
  }) {
    return [
      'page=$page',
      'size=$size',
      'keyword=${keyword ?? ''}',
      'category=${category ?? ''}',
      'brand=${brand ?? ''}',
      'isActive=${isActive ?? ''}',
      'isDeleted=$isDeleted',
    ].join('|');
  }

  void _reload({int? page}) {
    setState(() {
      if (page != null) {
        _currentPage = page;
      }
      _future = _load();
    });
  }

  Future<void> _deleteProduct(String id) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final ok =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Xóa sản phẩm'),
            content: const Text('Bạn có chắc muốn xóa sản phẩm này?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) {
      return;
    }

    try {
      await widget.dataSource.deleteProduct(token, id);
      if (!mounted) {
        return;
      }
      _reload();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa sản phẩm.')));
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Xóa sản phẩm thất bại')),
      );
    }
  }

  Future<void> _toggleStatus(
    Map<String, dynamic> product, {
    bool? targetActive,
  }) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = '${product['id'] ?? ''}'.trim();
    if (id.isEmpty || _togglingProductIds.contains(id)) {
      return;
    }

    final current = _isProductActive(product);
    final nextValue = targetActive ?? !current;

    setState(() {
      _activeOverrides[id] = nextValue;
      _togglingProductIds.add(id);
    });

    try {
      await widget.dataSource.updateProductStatus(token, id, active: nextValue);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật trạng thái sản phẩm: ${nextValue ? 'Bật' : 'Tắt'}',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeOverrides[id] = current;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Cập nhật trạng thái thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingProductIds.remove(id);
        });
      }
    }
  }

  Future<void> _openProductEditor({Map<String, dynamic>? existing}) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => _ProductEditorSheet(
        dataSource: widget.dataSource,
        token: token,
        existing: existing,
      ),
    );

    if (changed == true && mounted) {
      _reload();
    }
  }

  Future<void> _openAssetManager(Map<String, dynamic> product) async {
    final token = widget.authController.session?.token;
    final productId = '${product['id'] ?? ''}'.trim();
    if (token == null || token.isEmpty || productId.isEmpty) {
      return;
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => _ProductAssetsSheet(
        dataSource: widget.dataSource,
        token: token,
        productId: productId,
        productName:
            '${product['name'] ?? product['productName'] ?? 'Sản phẩm'}',
      ),
    );

    if (changed == true && mounted) {
      _reload();
    }
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    return '${NumberFormat.decimalPattern('vi_VN').format(amount.round())}đ';
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == 'active' ||
        normalized == 'enabled' ||
        normalized == 'on';
  }

  bool _isProductActive(Map<String, dynamic> product) {
    final id = '${product['id'] ?? ''}'.trim();
    final local = _activeOverrides[id];
    if (local != null) {
      return local;
    }

    // isActive is the primary source of truth from backend.
    final directKeys = <String>[
      'isActive',
      'is_active',
      'active',
      'enabled',
      'isEnabled',
      'is_enabled',
    ];

    for (final key in directKeys) {
      if (product.containsKey(key)) {
        final raw = product[key];
        if ('$raw'.trim().isEmpty || '$raw'.trim().toLowerCase() == 'null') {
          continue;
        }
        return _isTruthy(raw);
      }
    }

    final statusKeys = <String>['status', 'productStatus', 'state'];
    for (final key in statusKeys) {
      final raw = '${product[key] ?? ''}'.trim().toLowerCase();
      if (raw.isEmpty) {
        continue;
      }

      if (raw == 'active' || raw == 'enabled' || raw == 'on') {
        return true;
      }
      if (raw == 'inactive' ||
          raw == 'disabled' ||
          raw == 'off' ||
          raw == 'deleted') {
        return false;
      }
    }

    return false;
  }

  String _productThumbnailUrl(Map<String, dynamic> product) {
    final candidates = <dynamic>[
      product['thumbnailUrl'],
      product['imageUrl'],
      product['mainImageUrl'],
      product['mainImage'],
      product['coverImage'],
    ];

    for (final candidate in candidates) {
      final text = '$candidate'.trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  String _statusFilterLabel() {
    return 'Trạng thái: ${_productStatusLabel(_selectedStatus)}';
  }

  String _categoryFilterLabel() {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      return 'Danh mục: Tất cả';
    }
    return 'Danh mục: $_selectedCategory';
  }

  String _brandFilterLabel() {
    if (_selectedBrand == null || _selectedBrand!.isEmpty) {
      return 'Thương hiệu: Tất cả';
    }
    return 'Thương hiệu: $_selectedBrand';
  }

  Future<void> _onProductMenuAction(
    String action,
    Map<String, dynamic> product,
  ) async {
    final id = '${product['id'] ?? ''}'.trim();
    switch (action) {
      case 'edit':
        await _openProductEditor(existing: product);
        break;
      case 'toggle':
        await _toggleStatus(product, targetActive: !_isProductActive(product));
        break;
      case 'assets':
        await _openAssetManager(product);
        break;
      case 'delete':
        if (id.isNotEmpty) {
          await _deleteProduct(id);
        }
        break;
    }
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedStatus = value;
              });
              _reload(page: 0);
            },
            itemBuilder: (context) => _statusFilters
                .map(
                  (value) => PopupMenuItem<String>(
                    value: value,
                    child: Text(_productStatusLabel(value)),
                  ),
                )
                .toList(),
            child: _filterChip(_statusFilterLabel(), Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            onSelected: (value) {
              setState(() {
                _selectedCategory = value;
              });
              _reload(page: 0);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('Tất cả danh mục'),
              ),
              ..._categories.map(
                (c) => PopupMenuItem<String?>(
                  value: '${c['name'] ?? c['slug'] ?? ''}',
                  child: Text('${c['name'] ?? c['id']}'),
                ),
              ),
            ],
            child: _filterChip(_categoryFilterLabel(), Icons.category_outlined),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            onSelected: (value) {
              setState(() {
                _selectedBrand = value;
              });
              _reload(page: 0);
            },
            itemBuilder: (context) => [
              const PopupMenuItem<String?>(
                value: null,
                child: Text('Tất cả thương hiệu'),
              ),
              ..._brands.map(
                (b) => PopupMenuItem<String?>(
                  value: '${b['name'] ?? ''}',
                  child: Text('${b['name'] ?? b['id']}'),
                ),
              ),
            ],
            child: _filterChip(
              _brandFilterLabel(),
              Icons.workspace_premium_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final id = '${product['id'] ?? ''}';
    final name = '${product['name'] ?? product['productName'] ?? 'N/A'}';
    final price = product['basePrice'] ?? product['price'] ?? 0;
    final active = _isProductActive(product);
    final isToggling = _togglingProductIds.contains(id);
    final thumbnailUrl = _productThumbnailUrl(product);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AdminProductDetailPage(
                product: product,
                authController: widget.authController,
                dataSource: widget.dataSource,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 74,
                  height: 74,
                  color: AppColors.surfaceContainerLow,
                  child: thumbnailUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.textSecondary,
                        )
                      : Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatMoney(price),
                                style: const TextStyle(
                                  color: AppColors.primaryContainer,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'ID: $id',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontFamily: 'monospace',
                                    ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) =>
                              _onProductMenuAction(value, product),
                          itemBuilder: (context) => [
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Sửa'),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'toggle',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  active
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                title: Text(
                                  active ? 'Tắt sản phẩm' : 'Bật sản phẩm',
                                ),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'assets',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.layers_outlined),
                                title: Text('Biến thể/Hình ảnh'),
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                title: Text('Xóa'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primaryContainer
                                : AppColors.textSecondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          active ? 'Đang bật' : 'Đang tắt',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const Spacer(),
                        Switch.adaptive(
                          value: active,
                          onChanged: id.isEmpty || isToggling
                              ? null
                              : (value) =>
                                    _toggleStatus(product, targetActive: value),
                          activeThumbColor: AppColors.primaryContainer,
                          activeTrackColor: AppColors.primaryContainer
                              .withValues(alpha: 0.45),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              AdminTopBar(
                title: 'QUẢN LÝ SẢN PHẨM',
                role: widget.authController.userRole ?? 'ADMIN',
                onLogout: () => widget.authController.logout(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Tìm kiếm sản phẩm',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) {
                                _reload(page: 0);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFilterChips(),
              const SizedBox(height: 12),
              FutureBuilder<AdminPageResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        snapshot.error?.toString() ??
                            'Không thể tải danh sách sản phẩm',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final result = snapshot.data!;
                  if (result.items.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('Không tìm thấy sản phẩm nào'),
                    );
                  }

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tổng: $_totalElements',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.items.map(
                        (product) => _buildProductCard(context, product),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _currentPage > 0
                                ? () => _reload(page: _currentPage - 1)
                                : null,
                            child: const Text('Trước'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Trang ${_currentPage + 1}/$_totalPages',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _currentPage + 1 < _totalPages
                                ? () => _reload(page: _currentPage + 1)
                                : null,
                            child: const Text('Sau'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 22,
          child: FloatingActionButton(
            onPressed: () => _openProductEditor(),
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
            tooltip: 'Thêm sản phẩm',
            child: const Icon(Icons.add_rounded),
          ),
        ),
      ],
    );
  }
}

class _ProductAssetsSheet extends StatefulWidget {
  const _ProductAssetsSheet({
    required this.dataSource,
    required this.token,
    required this.productId,
    required this.productName,
  });

  final AdminRemoteDataSource dataSource;
  final String token;
  final String productId;
  final String productName;

  @override
  State<_ProductAssetsSheet> createState() => _ProductAssetsSheetState();
}

class _ProductAssetsSheetState extends State<_ProductAssetsSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  bool _changed = false;
  List<Map<String, dynamic>> _variants = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _images = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        widget.dataSource.getProductVariants(widget.token, widget.productId),
        widget.dataSource.getProductImages(widget.token, widget.productId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _variants = results[0];
        _images = results[1];
      });
    } catch (_) {
      // Keep sheet visible with empty sections.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    final id = '${variant['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.deleteProductVariant(
        widget.token,
        widget.productId,
        id,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openVariantEditor({Map<String, dynamic>? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => _VariantEditorSheet(
        dataSource: widget.dataSource,
        token: widget.token,
        productId: widget.productId,
        existing: existing,
      ),
    );

    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final id = '${image['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.deleteProductImage(
        widget.token,
        widget.productId,
        id,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editImageMeta(Map<String, dynamic> image) async {
    final id = '${image['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    final colorController = TextEditingController(
      text: '${image['color'] ?? ''}',
    );
    bool isMain = image['isMain'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sửa thông tin ảnh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Màu'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ảnh chính'),
                value: isMain,
                onChanged: (value) {
                  setLocal(() {
                    isMain = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      colorController.dispose();
      return;
    }

    try {
      await widget.dataSource.updateProductImage(
        widget.token,
        widget.productId,
        id,
        {'color': colorController.text.trim(), 'isMain': isMain},
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      colorController.dispose();
    }
  }

  Future<void> _uploadImage() async {
    final colorController = TextEditingController();
    bool isMain = false;

    final ready = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tải ảnh sản phẩm lên'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Màu (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ảnh chính'),
                value: isMain,
                onChanged: (value) {
                  setLocal(() {
                    isMain = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );

    if (ready != true) {
      colorController.dispose();
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) {
      colorController.dispose();
      return;
    }

    try {
      await widget.dataSource.uploadProductImage(
        widget.token,
        widget.productId,
        filePath: picked.path,
        color: colorController.text.trim().isEmpty
            ? null
            : colorController.text.trim(),
        isMain: isMain,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      colorController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài nguyên: ${widget.productName}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Biến thể (${_variants.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => _openVariantEditor(),
                          child: const Text('Thêm biến thể'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._variants.map((variant) {
                      final variantId = '${variant['id'] ?? ''}';
                      final sku = '${variant['sku'] ?? ''}';
                      final size = '${variant['size'] ?? ''}';
                      final color = '${variant['color'] ?? ''}';
                      final price = '${variant['price'] ?? 0}';
                      final stock = '${variant['stock'] ?? 0}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: $variantId | SKU: $sku'),
                            const SizedBox(height: 4),
                            Text(
                              'Kích thước: $size | Màu: $color | Giá: $price | Tồn kho: $stock',
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _openVariantEditor(existing: variant),
                                  child: const Text('Sửa'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteVariant(variant),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Hình ảnh (${_images.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _uploadImage,
                          child: const Text('Tải ảnh lên'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._images.map((image) {
                      final url = '${image['imageUrl'] ?? image['url'] ?? ''}';
                      final color = '${image['color'] ?? ''}';
                      final isMain = image['isMain'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (url.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text('Màu: $color | Ảnh chính: $isMain'),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _editImageMeta(image),
                                  child: const Text('Sửa thông tin ảnh'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteImage(image),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_changed),
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VariantEditorSheet extends StatefulWidget {
  const _VariantEditorSheet({
    required this.dataSource,
    required this.token,
    required this.productId,
    this.existing,
  });

  final AdminRemoteDataSource dataSource;
  final String token;
  final String productId;
  final Map<String, dynamic>? existing;

  @override
  State<_VariantEditorSheet> createState() => _VariantEditorSheetState();
}

class _VariantEditorSheetState extends State<_VariantEditorSheet> {
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _gripController = TextEditingController();
  final _stiffnessController = TextEditingController();
  final _balancePointController = TextEditingController();
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _skuController.text = '${existing['sku'] ?? ''}';
      _weightController.text = '${existing['weight'] ?? ''}';
      _gripController.text = '${existing['gripSize'] ?? ''}';
      _stiffnessController.text = '${existing['stiffness'] ?? ''}';
      _balancePointController.text = '${existing['balancePoint'] ?? ''}';
      _sizeController.text = '${existing['size'] ?? ''}';
      _colorController.text = '${existing['color'] ?? ''}';
      _priceController.text = '${existing['price'] ?? ''}';
      _stockController.text = '${existing['stock'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    _gripController.dispose();
    _stiffnessController.dispose();
    _balancePointController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sku = _skuController.text.trim();
    final size = _sizeController.text.trim();
    final color = _colorController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (sku.isEmpty ||
        size.isEmpty ||
        color.isEmpty ||
        price == null ||
        stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SKU, kích thước, màu, giá và tồn kho là bắt buộc.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = <String, dynamic>{
      'sku': sku,
      'weight': _weightController.text.trim(),
      'gripSize': _gripController.text.trim(),
      'stiffness': _stiffnessController.text.trim(),
      'balancePoint': _balancePointController.text.trim(),
      'size': size,
      'color': color,
      'price': price,
      'stock': stock,
    };

    try {
      if (_isEdit) {
        final variantId = '${widget.existing?['id'] ?? ''}';
        await widget.dataSource.updateProductVariant(
          widget.token,
          widget.productId,
          variantId,
          payload,
        );
      } else {
        await widget.dataSource.createProductVariant(
          widget.token,
          widget.productId,
          payload,
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lưu biến thể thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Sửa biến thể' : 'Tạo biến thể',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Kích thước',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Màu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tồn kho',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Trọng lượng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gripController,
              decoration: const InputDecoration(
                labelText: 'Cỡ cán',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stiffnessController,
              decoration: const InputDecoration(
                labelText: 'Độ cứng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _balancePointController,
              decoration: const InputDecoration(
                labelText: 'Điểm cân bằng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Lưu thay đổi' : 'Tạo biến thể'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductEditorSheet extends StatefulWidget {
  const _ProductEditorSheet({
    required this.dataSource,
    required this.token,
    this.existing,
  });

  final AdminRemoteDataSource dataSource;
  final String token;
  final Map<String, dynamic>? existing;

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  final _nameController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _basePriceController = TextEditingController();

  bool _saving = false;
  List<Map<String, dynamic>> _brands = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _categories = const <Map<String, dynamic>>[];
  final AdminMasterDataLocalDataSource _localMasterData =
      AdminMasterDataLocalDataSource();
  String? _brandId;
  String? _categoryId;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _nameController.text = '${existing['name'] ?? ''}';
      _shortDescriptionController.text =
          '${existing['shortDescription'] ?? ''}';
      _descriptionController.text = '${existing['description'] ?? ''}';
      _basePriceController.text =
          '${existing['basePrice'] ?? existing['price'] ?? ''}';
      _brandId = '${existing['brandId'] ?? ''}'.trim().isEmpty
          ? null
          : '${existing['brandId']}';
      _categoryId = '${existing['categoryId'] ?? ''}'.trim().isEmpty
          ? null
          : '${existing['categoryId']}';
    }
    _loadMasterData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _shortDescriptionController.dispose();
    _descriptionController.dispose();
    _basePriceController.dispose();
    super.dispose();
  }

  Future<void> _loadMasterData() async {
    try {
      final cachedBrands = await _localMasterData.getCachedBrands();
      final cachedCategories = await _localMasterData.getCachedCategories();
      if (mounted && (cachedBrands.isNotEmpty || cachedCategories.isNotEmpty)) {
        setState(() {
          if (cachedBrands.isNotEmpty) {
            _brands = cachedBrands;
          }
          if (cachedCategories.isNotEmpty) {
            _categories = cachedCategories;
          }
        });
      }

      if (cachedBrands.isNotEmpty && cachedCategories.isNotEmpty) {
        return;
      }
    } catch (_) {
      // Ignore cache read failures and continue with remote source.
    }

    try {
      final brands = await widget.dataSource.getBrands(widget.token);
      final categories = await widget.dataSource.getCategories(widget.token);
      if (!mounted) {
        return;
      }
      setState(() {
        _brands = brands;
        _categories = categories;
      });

      await _localMasterData.cacheBrands(brands);
      await _localMasterData.cacheCategories(categories);
    } catch (_) {
      // Keep sheet usable even if brand/category list fails.
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final price = double.tryParse(_basePriceController.text.trim());

    if (name.isEmpty || price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tên và giá cơ bản hợp lệ là bắt buộc.')),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final payload = <String, dynamic>{
        'name': name,
        'shortDescription': _shortDescriptionController.text.trim(),
        'description': _descriptionController.text.trim(),
        'basePrice': price,
        if (_categoryId != null) 'categoryId': int.tryParse(_categoryId!),
        if (_brandId != null) 'brandId': int.tryParse(_brandId!),
      };

      if (_isEdit) {
        final id = '${widget.existing?['id'] ?? ''}';
        await widget.dataSource.updateProduct(widget.token, id, payload);
      } else {
        await widget.dataSource.createProduct(widget.token, payload);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lưu sản phẩm thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Sửa sản phẩm' : 'Tạo sản phẩm',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên sản phẩm',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _shortDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả ngắn',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _descriptionController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _basePriceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá cơ bản',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              items: _categories
                  .map(
                    (c) => DropdownMenuItem<String>(
                      value: '${c['id']}',
                      child: Text('${c['name'] ?? c['id']}'),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Danh mục',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _categoryId = value;
                });
              },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _brandId,
              items: _brands
                  .map(
                    (b) => DropdownMenuItem<String>(
                      value: '${b['id']}',
                      child: Text('${b['name'] ?? b['id']}'),
                    ),
                  )
                  .toList(),
              decoration: const InputDecoration(
                labelText: 'Thương hiệu',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _brandId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Lưu thay đổi' : 'Tạo sản phẩm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _productStatusLabel(String value) {
  switch (value.toUpperCase()) {
    case 'ALL':
      return 'Tất cả';
    case 'ACTIVE':
      return 'Đang hoạt động';
    case 'INACTIVE':
      return 'Ngừng hoạt động';
    default:
      return value;
  }
}

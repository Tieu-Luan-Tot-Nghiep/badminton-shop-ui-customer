import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/shop_local_data_source.dart';
import '../../data/datasources/shop_remote_data_source.dart';
import '../../domain/entities/category_entity.dart';
import '../../domain/entities/product_entity.dart';
import 'auth_controller.dart';

class ShopController extends ChangeNotifier {
  ShopController(this._remote, this._local);

  final ShopRemoteDataSource _remote;
  final ShopLocalDataSource _local;

  bool isLoading = true;
  bool isSyncing = false;
  bool isLoadingMore = false;
  String? error;
  String? syncWarning;

  List<CategoryEntity> categories = const [];
  List<ProductEntity> products = const [];
  List<String> suggestions = const [];
  bool isScanResultMode = false;

  String keyword = '';
  String selectedCategorySlug = 'all';
  String sortBy = 'createdAt';
  String sortDir = 'desc';

  int _page = 0;
  final int _size = 8;
  bool hasMore = true;
  Timer? _debounce;
  int _operationToken = 0;

  Future<void> loadInitial() async {
    final opToken = ++_operationToken;
    isLoading = true;
    isSyncing = true;
    error = null;
    syncWarning = null;
    notifyListeners();

    final cachedCategories = await _local.getCachedCategories();
    final cachedProducts = await _local.getCachedFirstProducts();
    final hasCache = cachedProducts.isNotEmpty;

    if (hasCache) {
      if (opToken != _operationToken) {
        return;
      }
      categories = [
        const CategoryEntity(id: 'all', name: 'TAT CA', slug: 'all'),
        ...cachedCategories.map((e) => e.toEntity()),
      ];
      products = cachedProducts.map((e) => e.toEntity()).toList();
      isLoading = false;
      notifyListeners();
    }

    try {
      final remoteCategories = await _remote.getAllCategories();
      final categoryId = _resolveSelectedCategoryId();
      final query = keyword.trim();
      final page = await _fetchProductsPage(
        query: query,
        categoryId: categoryId,
        page: 0,
      );

      if (opToken != _operationToken) {
        return;
      }

      categories = [
        const CategoryEntity(id: 'all', name: 'TAT CA', slug: 'all'),
        ...remoteCategories.map((e) => e.toEntity()),
      ];
      products = page.items.map((e) => e.toEntity()).toList();
      _page = page.page;
      hasMore = page.hasMore;

      if (categoryId == null && query.isEmpty) {
        await _local.cacheFirstPage(
          categories: remoteCategories,
          products: page.items,
        );
      }

      error = null;
    } catch (e) {
      if (!hasCache) {
        error = 'Khong tai duoc du lieu Shop. ${e.toString()}';
      } else {
        syncWarning = _buildSyncWarningMessage(e);
      }
    } finally {
      if (opToken == _operationToken) {
        isLoading = false;
        isSyncing = false;
        notifyListeners();
      }
    }
  }

  String _buildSyncWarningMessage(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Khong the ket noi may chu. Dang hien thi du lieu offline da luu.';
      }

      final status = error.response?.statusCode;
      final serverMsg = error.response?.data?.toString() ?? error.message;
      return 'Lỗi đồng bộ (HTTP $status): $serverMsg. Dang hien thi du lieu da luu.';
    }

    return 'Lỗi đồng bộ: ${error.toString()}. Dang hien thi du lieu da luu.';
  }

  Future<void> refresh() async {
    _page = 0;
    hasMore = true;
    await _loadPage(reset: true);
  }

  void onKeywordChanged(String value) {
    keyword = value;

    if (value.trim().isEmpty) {
      suggestions = const [];
      _debounce?.cancel();
      _page = 0;
      hasMore = true;
      _loadPage(reset: true);
      notifyListeners();
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final text = keyword.trim();
      if (text.isEmpty) {
        return;
      }
      suggestions = await _remote.suggestKeywords(query: text, size: 6);
      notifyListeners();
    });
  }

  Future<void> applySearch({String? forceKeyword}) async {
    if (forceKeyword != null) {
      keyword = forceKeyword;
    }

    suggestions = const [];
    isScanResultMode = false;
    _page = 0;
    hasMore = true;
    await _loadPage(reset: true);
  }

  void applyScanResults(List<ProductEntity> scanProducts) {
    _operationToken++;
    isLoading = false;
    isLoadingMore = false;
    error = null;
    suggestions = const [];
    keyword = '';
    isScanResultMode = true;
    products = List<ProductEntity>.unmodifiable(scanProducts);
    _page = 0;
    hasMore = false;
    syncWarning = scanProducts.isEmpty
        ? 'Không tìm thấy sản phẩm phù hợp từ hình ảnh đã chọn.'
        : null;
    notifyListeners();
    
    if (categories.isEmpty) {
      _loadCategoriesOnly();
    }
  }

  Future<void> _loadCategoriesOnly() async {
    try {
      final cachedCategories = await _local.getCachedCategories();
      if (cachedCategories.isNotEmpty) {
        categories = [
          const CategoryEntity(id: 'all', name: 'TAT CA', slug: 'all'),
          ...cachedCategories.map((e) => e.toEntity()),
        ];
        notifyListeners();
      }
      
      final remoteCategories = await _remote.getAllCategories();
      categories = [
        const CategoryEntity(id: 'all', name: 'TAT CA', slug: 'all'),
        ...remoteCategories.map((e) => e.toEntity()),
      ];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> selectCategory(String slug) async {
    selectedCategorySlug = slug;
    _page = 0;
    hasMore = true;
    await _loadPage(reset: true);
  }

  Future<void> setSort({required String by, required String dir}) async {
    sortBy = by;
    sortDir = dir;
    _page = 0;
    hasMore = true;
    await _loadPage(reset: true);
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore || isLoading) {
      return;
    }

    await _loadPage(reset: false);
  }

  Future<void> _loadPage({required bool reset}) async {
    final opToken = ++_operationToken;
    isScanResultMode = false;
    if (reset) {
      isLoading = true;
      error = null;
      syncWarning = null;
      notifyListeners();
    } else {
      isLoadingMore = true;
      notifyListeners();
    }

    try {
      final targetPage = reset ? 0 : _page + 1;
      final categoryId = _resolveSelectedCategoryId();
      final query = keyword.trim();
      final page = await _fetchProductsPage(
        query: query,
        categoryId: categoryId,
        page: targetPage,
      );

      if (opToken != _operationToken) {
        return;
      }

      final data = page.items.map((e) => e.toEntity()).toList();
      products = reset ? data : [...products, ...data];
      _page = page.page;
      hasMore = page.hasMore;
      error = null;
    } catch (e) {
      if (products.isEmpty) {
        error = 'Khong tai duoc danh sach san pham. ${e.toString()}';
      }
    } finally {
      if (opToken == _operationToken) {
        isLoading = false;
        isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  String? _resolveSelectedCategoryId() {
    if (selectedCategorySlug == 'all') {
      return null;
    }

    for (final item in categories) {
      if (item.slug == selectedCategorySlug) {
        final id = item.id.trim();
        return id.isEmpty ? null : id;
      }
    }

    return null;
  }

  Future<ShopProductPageModel> _fetchProductsPage({
    required String query,
    required String? categoryId,
    required int page,
  }) {
    if (query.isNotEmpty) {
      return _remote.searchProducts(
        keyword: query,
        sortBy: sortBy,
        sortDir: sortDir,
        page: page,
        size: _size,
      );
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      return _remote.getProductsByCategoryId(
        categoryId: categoryId,
        sortBy: sortBy,
        sortDir: sortDir,
        page: page,
        size: _size,
      );
    }

    return _remote.getProducts(
      sortBy: sortBy,
      sortDir: sortDir,
      page: page,
      size: _size,
    );
  }

  Future<ShopAddToCartResult> addProductToCart({
    required ProductEntity product,
    required AuthController authController,
  }) async {
    if (!authController.isAuthenticated) {
      return ShopAddToCartResult.needLogin;
    }

    try {
      final variantId = await _remote.getDefaultVariantId(product.id);
      if (variantId == null) {
        return ShopAddToCartResult.failed;
      }

      await _remote.addToCart(
        variantId: variantId,
        quantity: 1,
        accessToken: authController.session?.token,
      );
      return ShopAddToCartResult.success;
    } catch (_) {
      return ShopAddToCartResult.failed;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

enum ShopAddToCartResult { success, failed, needLogin }

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class ShopRemoteDataSource {
  ShopRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<CategoryModel>> getAllCategories() async {
    final response = await _dio.get('/api/categories');
    return _parseList(response.data).map(CategoryModel.fromJson).toList();
  }

  Future<ShopProductPageModel> getProducts({
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    String? keyword,
    String? sortBy,
    String? sortDir,
    int page = 0,
    int size = 8,
  }) async {
    final response = await _dio.get(
      '/api/products',
      queryParameters: {
        if (category != null && category.isNotEmpty) 'category': category,
        if (brand != null && brand.isNotEmpty) 'brand': brand,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
        if (sortDir != null && sortDir.isNotEmpty) 'sortDir': sortDir,
        'page': page,
        'size': size,
      },
    );

    return _parsePagedProducts(response.data, page: page, size: size);
  }

  Future<ShopProductPageModel> getProductsByCategoryId({
    required String categoryId,
    String? sortBy,
    String? sortDir,
    int page = 0,
    int size = 8,
  }) async {
    final response = await _dio.get(
      '/api/products/categories/$categoryId',
      queryParameters: {
        if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
        if (sortDir != null && sortDir.isNotEmpty) 'sortDir': sortDir,
        'page': page,
        'size': size,
      },
    );

    return _parsePagedProducts(response.data, page: page, size: size);
  }

  Future<ShopProductPageModel> searchProducts({
    required String keyword,
    String? sortBy,
    String? sortDir,
    int page = 0,
    int size = 8,
  }) async {
    final response = await _dio.get(
      '/api/search/products',
      queryParameters: {
        'keyword': keyword,
        if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
        if (sortDir != null && sortDir.isNotEmpty) 'sortDir': sortDir,
        'page': page,
        'size': size,
      },
    );

    return _parsePagedProducts(response.data, page: page, size: size);
  }

  Future<ShopProductPageModel> searchProductsByImage({
    required String imagePath,
    String? accessToken,
    int page = 0,
    int size = 12,
  }) async {
    const endpoint = '/api/search/products/by-image';
    const fileKeys = <String>['image', 'file'];

    DioException? lastError;

    for (final fileKey in fileKeys) {
      try {
        _logImageSearchDebug('REQUEST', {
          'method': 'POST',
          'url': endpoint,
          'query': {'page': page, 'size': size, 'activeOnly': true},
          'fileKey': fileKey,
          'fileName': path.basename(imagePath),
          'hasToken': accessToken != null && accessToken.isNotEmpty,
        });

        final response = await _dio.post(
          endpoint,
          queryParameters: {'page': page, 'size': size, 'activeOnly': true},
          data: FormData.fromMap({
            fileKey: await MultipartFile.fromFile(
              imagePath,
              filename: path.basename(imagePath),
            ),
          }),
          options: accessToken == null || accessToken.isEmpty
              ? null
              : Options(headers: {'Authorization': 'Bearer $accessToken'}),
        );

        _logImageSearchDebug('RESPONSE', {
          'statusCode': response.statusCode,
          'statusMessage': response.statusMessage,
          'data': _truncate('${response.data}', max: 5000),
        });

        return _parsePagedProducts(response.data, page: page, size: size);
      } on DioException catch (e) {
        lastError = e;
        _logImageSearchDebug('ERROR', {
          'message': e.message,
          'statusCode': e.response?.statusCode,
          'statusMessage': e.response?.statusMessage,
          'response': _truncate('${e.response?.data}', max: 5000),
          'fileKey': fileKey,
        });
        final code = e.response?.statusCode ?? 0;
        if (code == 400 || code == 404 || code == 405) {
          continue;
        }
        rethrow;
      }
    }

    throw AppException(
      'Khong the goi endpoint tim kiem bang hinh anh /api/search/products/by-image. '
      '${lastError?.message ?? ''}',
    );
  }

  Future<List<String>> suggestKeywords({
    required String query,
    int size = 6,
  }) async {
    final response = await _dio.get(
      '/api/search/products/suggestions',
      queryParameters: {'query': query, 'size': size},
    );

    final payload = response.data;
    if (payload is List) {
      return payload.map((e) => '$e').where((e) => e.isNotEmpty).toList();
    }

    if (payload is Map<String, dynamic>) {
      final listCandidate =
          payload['suggestions'] ?? payload['keywords'] ?? payload['data'];
      if (listCandidate is List) {
        return listCandidate
            .map(
              (e) => e is Map<String, dynamic>
                  ? '${e['keyword'] ?? e['value'] ?? ''}'
                  : '$e',
            )
            .where((e) => e.isNotEmpty)
            .toList();
      }
    }

    return const [];
  }

  Future<int?> getDefaultVariantId(String productId) async {
    final detail = await getProductDetail(productId);
    if (detail.variants.isEmpty) {
      return null;
    }

    ShopProductVariantModel? fallback;
    for (final item in detail.variants) {
      fallback ??= item;
      final stock = item.stock;
      if (stock > 0) {
        return item.id;
      }
    }

    if (fallback == null) {
      return null;
    }
    return fallback.id;
  }

  Future<ShopProductDetailModel> getProductDetail(String productId) async {
    final response = await _dio.get('/api/products/$productId');
    final payload = response.data;

    if (payload is! Map<String, dynamic>) {
      throw const AppException('Unexpected product detail payload format');
    }

    final map = _pickEnvelope(payload);
    return ShopProductDetailModel.fromJson(map);
  }

  Future<void> addToCart({
    required int variantId,
    int quantity = 1,
    String? accessToken,
  }) async {
    await _dio.post(
      '/api/cart/items',
      data: {'variantId': variantId, 'quantity': quantity},
      options: accessToken == null || accessToken.isEmpty
          ? null
          : Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );
  }

  Future<List<ShopProductReviewModel>> getProductReviews({
    required String productId,
    int page = 0,
    int size = 5,
  }) async {
    final response = await _dio.get(
      '/api/reviews/products/$productId',
      queryParameters: {'page': page, 'size': size},
    );

    final payload = response.data;
    final map = _pickEnvelope(payload);
    final rows = _extractItems(map) ?? _extractItems(payload) ?? const [];
    return rows.map(ShopProductReviewModel.fromJson).toList();
  }

  Future<ShopProductReviewSummaryModel?> getProductReviewSummary({
    required String productId,
  }) async {
    final response = await _dio.get('/api/reviews/products/$productId/summary');
    final payload = response.data;

    if (payload is! Map<String, dynamic>) {
      return null;
    }

    final map = _pickEnvelope(payload);
    return ShopProductReviewSummaryModel.fromJson(map);
  }

  Future<ShopProductRecommendationsModel> getProductRecommendations({
    required String productId,
    int size = 6,
    bool withAi = false,
  }) async {
    // Try the dedicated KNN recommendations endpoint first.
    try {
      final response = await _dio.get(
        '/api/products/$productId/recommendations',
        queryParameters: {'size': size, 'withAi': withAi},
      );
      final map = _pickEnvelope(response.data);
      final result = ShopProductRecommendationsModel.fromJson(map);
      if (result.recommendations.isNotEmpty) return result;
    } catch (_) {}

    // Fallback: similar products search (Elasticsearch, same-category matching).
    final fallback = await _dio.get(
      '/api/search/products/similar',
      queryParameters: {
        'productId': productId,
        'size': size,
        'activeOnly': true,
      },
    );
    final page = _parsePagedProducts(fallback.data, page: 0, size: size);
    final items = page.items
        .map(
          (p) => ShopProductRecommendationItemModel(
            id: int.tryParse(p.id) ?? 0,
            name: p.name,
            slug: p.id,
            basePrice: p.price,
            brandName: '',
            categoryName: '',
            thumbnailUrl: p.imageUrl,
          ),
        )
        .toList();

    return ShopProductRecommendationsModel(
      recommendations: items,
      aiInsight: null,
      aiInsightEnabled: false,
    );
  }

  List<Map<String, dynamic>> _parseList(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }

    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.whereType<Map<String, dynamic>>().toList();
      }
    }

    throw const AppException('Unexpected API payload format');
  }

  ShopProductPageModel _parsePagedProducts(
    dynamic payload, {
    required int page,
    required int size,
  }) {
    final map = _pickEnvelope(payload);

    final rawItems = _extractItems(map) ?? _extractItems(payload);
    if (rawItems != null) {
      final items = rawItems.map(ProductModel.fromJson).toList();
      final totalPages = _toInt(
        map['totalPages'] ?? map['pages'] ?? map['pageCount'],
      );
      final totalElements = _toInt(
        map['totalElements'] ??
            map['total'] ??
            map['totalItems'] ??
            map['count'],
      );
      final resolvedPage = _toInt(
        map['number'] ?? map['page'] ?? map['currentPage'] ?? page,
      );

      final resolvedTotalPages = totalPages > 0
          ? totalPages
          : (totalElements > 0 ? ((totalElements / size).ceil()) : 1);

      return ShopProductPageModel(
        items: items,
        page: resolvedPage,
        totalPages: resolvedTotalPages,
        totalElements: totalElements > 0 ? totalElements : items.length,
      );
    }

    final dataList = _parseList(payload).map(ProductModel.fromJson).toList();
    return ShopProductPageModel(
      items: dataList,
      page: page,
      totalPages: dataList.length < size ? page + 1 : page + 2,
      totalElements: dataList.length,
    );
  }

  Map<String, dynamic> _pickEnvelope(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    }
    return const {};
  }

  List<Map<String, dynamic>>? _extractItems(dynamic payload) {
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }

    if (payload is! Map<String, dynamic>) {
      return null;
    }

    const keys = [
      'content',
      'items',
      'records',
      'products',
      'result',
      'data',
      'list',
    ];

    for (final key in keys) {
      final value = payload[key];
      if (value is List) {
        return value.whereType<Map<String, dynamic>>().toList();
      }
      if (value is Map<String, dynamic>) {
        final nested = _extractItems(value);
        if (nested != null) {
          return nested;
        }
      }
    }

    return null;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  void _logImageSearchDebug(String phase, Map<String, Object?> payload) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('[ImageSearch][$phase] $payload');
  }

  String _truncate(String value, {int max = 2000}) {
    if (value.length <= max) {
      return value;
    }
    return '${value.substring(0, max)}...(truncated)';
  }
}

class ShopProductPageModel {
  const ShopProductPageModel({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalElements,
  });

  final List<ProductModel> items;
  final int page;
  final int totalPages;
  final int totalElements;

  bool get hasMore => page + 1 < totalPages;
}

class ShopProductDetailModel {
  const ShopProductDetailModel({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.shortDescription,
    required this.rating,
    required this.images,
    required this.variants,
  });

  final String id;
  final String name;
  final double price;
  final String description;
  final String shortDescription;
  final double rating;
  final List<String> images;
  final List<ShopProductVariantModel> variants;

  factory ShopProductDetailModel.fromJson(Map<String, dynamic> json) {
    final variantsRaw = json['productVariants'];
    final imagesRaw = json['productImages'];

    final variants = variantsRaw is List
        ? variantsRaw
              .whereType<Map<String, dynamic>>()
              .map(ShopProductVariantModel.fromJson)
              .toList()
        : const <ShopProductVariantModel>[];

    final images = <String>[];
    final seen = <String>{};

    void pushImage(dynamic value) {
      final text = '$value'.trim();
      if (text.isEmpty || seen.contains(text)) {
        return;
      }
      seen.add(text);
      images.add(text);
    }

    // Keep explicit product image gallery order first to match backend ordering.
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is String) {
          pushImage(item);
          continue;
        }
        if (item is Map<String, dynamic>) {
          final url = item['imageUrl'] ?? item['url'];
          if (url != null) {
            pushImage(url);
          }
        }
      }
    }
    pushImage(json['thumbnailUrl']);
    pushImage(json['imageUrl']);

    final computedPrice = variants.isNotEmpty
        ? variants
              .map((v) => v.price)
              .where((p) => p > 0)
              .fold<double>(
                0,
                (prev, value) => prev == 0 || value < prev ? value : prev,
              )
        : 0;

    return ShopProductDetailModel(
      id: '${json['id'] ?? json['productId'] ?? ''}',
      name: '${json['name'] ?? json['productName'] ?? 'Unknown Product'}',
      price: _toDoubleSafe(json['basePrice'] ?? json['price'] ?? computedPrice),
      description: '${json['description'] ?? ''}',
      shortDescription: '${json['shortDescription'] ?? ''}',
      rating: _toDoubleSafe(json['rating'] ?? 4.9),
      images: images.toList(),
      variants: variants,
    );
  }
}

class ShopProductVariantModel {
  const ShopProductVariantModel({
    required this.id,
    required this.size,
    required this.color,
    required this.price,
    required this.stock,
  });

  final int id;
  final String size;
  final String color;
  final double price;
  final int stock;

  factory ShopProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ShopProductVariantModel(
      id: _toIntSafe(json['id'] ?? json['variantId']),
      size: '${json['size'] ?? ''}',
      color: '${json['color'] ?? ''}',
      price: _toDoubleSafe(json['price'] ?? json['basePrice'] ?? 0),
      stock: _toIntSafe(json['stock'] ?? json['quantity'] ?? 0),
    );
  }
}

double _toDoubleSafe(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

int _toIntSafe(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}

class ShopProductReviewModel {
  const ShopProductReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.username,
    this.createdAt,
  });

  final String id;
  final double rating;
  final String comment;
  final String username;
  final String? createdAt;

  factory ShopProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ShopProductReviewModel(
      id: '${json['id'] ?? ''}',
      rating: _toDoubleSafe(json['rating'] ?? 0),
      comment: '${json['comment'] ?? ''}',
      username: '${json['username'] ?? json['userName'] ?? 'USER'}',
      createdAt: json['createdAt']?.toString(),
    );
  }
}

class ShopProductReviewSummaryModel {
  const ShopProductReviewSummaryModel({
    required this.averageRating,
    required this.totalReviews,
  });

  final double averageRating;
  final int totalReviews;

  factory ShopProductReviewSummaryModel.fromJson(Map<String, dynamic> json) {
    return ShopProductReviewSummaryModel(
      averageRating: _toDoubleSafe(
        json['averageRating'] ?? json['avgRating'] ?? json['rating'] ?? 0,
      ),
      totalReviews: _toIntSafe(
        json['totalReviews'] ?? json['total'] ?? json['count'] ?? 0,
      ),
    );
  }
}

class ShopProductRecommendationItemModel {
  const ShopProductRecommendationItemModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    required this.brandName,
    required this.categoryName,
    this.thumbnailUrl,
  });

  final int id;
  final String name;
  final String slug;
  final double basePrice;
  final String brandName;
  final String categoryName;
  final String? thumbnailUrl;

  factory ShopProductRecommendationItemModel.fromJson(
      Map<String, dynamic> json) {
    return ShopProductRecommendationItemModel(
      id: _toIntSafe(json['id'] ?? json['productId']),
      name: '${json['name'] ?? json['productName'] ?? ''}',
      slug: '${json['slug'] ?? ''}',
      basePrice: _toDoubleSafe(json['basePrice'] ?? json['price'] ?? 0),
      brandName: '${json['brandName'] ?? ''}',
      categoryName: '${json['categoryName'] ?? ''}',
      thumbnailUrl: json['thumbnailUrl']?.toString(),
    );
  }
}

class ShopProductRecommendationsModel {
  const ShopProductRecommendationsModel({
    required this.recommendations,
    this.aiInsight,
    this.aiInsightEnabled = false,
  });

  final List<ShopProductRecommendationItemModel> recommendations;
  final String? aiInsight;
  final bool aiInsightEnabled;

  factory ShopProductRecommendationsModel.fromJson(Map<String, dynamic> json) {
    final rawList = json['recommendations'];
    final items = rawList is List
        ? rawList
            .whereType<Map<String, dynamic>>()
            .map(ShopProductRecommendationItemModel.fromJson)
            .toList()
        : <ShopProductRecommendationItemModel>[];

    return ShopProductRecommendationsModel(
      recommendations: items,
      aiInsight: json['aiInsight']?.toString(),
      aiInsightEnabled: json['aiInsightEnabled'] == true,
    );
  }
}

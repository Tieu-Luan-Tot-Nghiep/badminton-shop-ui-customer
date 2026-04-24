import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class AdminPageResult {
  const AdminPageResult({
    required this.items,
    required this.page,
    required this.size,
    required this.totalElements,
    required this.totalPages,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int size;
  final int totalElements;
  final int totalPages;
}

class AdminRemoteDataSource {
  AdminRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Options _auth(String token) =>
      Options(headers: <String, String>{'Authorization': 'Bearer $token'});

  Future<List<Map<String, dynamic>>> getDashboardRevenue(
    String token, {
    String? startDate,
    String? endDate,
    String groupBy = 'DAY',
  }) async {
    final response = await _dio.get(
      '/api/admin/dashboard/revenue',
      options: _auth(token),
      queryParameters: {
        if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
        if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
        'groupBy': groupBy,
      },
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> getDashboardKpis(String token) async {
    final response = await _dio.get(
      '/api/admin/dashboard/kpis',
      options: _auth(token),
    );
    return _extractMap(response.data);
  }

  Future<List<Map<String, dynamic>>> getRecentOrders(String token) async {
    final response = await _dio.get(
      '/api/admin/dashboard/recent-orders',
      options: _auth(token),
    );
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> getAlerts(String token) async {
    final response = await _dio.get(
      '/api/admin/dashboard/alerts',
      options: _auth(token),
    );
    return _extractList(response.data);
  }

  Future<AdminPageResult> getOrders(
    String token, {
    int page = 0,
    int size = 20,
    String? keyword,
    String? status,
    String? paymentStatus,
    String? paymentMethod,
    String? from,
    String? to,
  }) async {
    final response = await _dio.get(
      '/api/orders/admin',
      options: _auth(token),
      queryParameters: {
        'page': page,
        'size': size,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (status != null && status.isNotEmpty) 'status': status,
        if (paymentStatus != null && paymentStatus.isNotEmpty)
          'paymentStatus': paymentStatus,
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'paymentMethod': paymentMethod,
        if (from != null && from.isNotEmpty) 'from': from,
        if (to != null && to.isNotEmpty) 'to': to,
      },
    );
    return _extractPage(response.data);
  }

  Future<Map<String, dynamic>> getOrderDetail(
    String token,
    String orderCode,
  ) async {
    final response = await _dio.get(
      '/api/orders/admin/$orderCode',
      options: _auth(token),
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> updateOrderStatus(
    String token,
    String orderCode, {
    required String status,
    String? note,
  }) async {
    final response = await _dio.patch(
      '/api/orders/admin/$orderCode/status',
      options: _auth(token),
      queryParameters: {
        'status': status,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> assignShipping(
    String token,
    String orderCode, {
    required String shippingCode,
    required String shippingProvider,
    String? expectedDeliveryAt,
  }) async {
    final response = await _dio.post(
      '/api/orders/admin/$orderCode/assign-shipping',
      options: _auth(token),
      queryParameters: {
        'shippingCode': shippingCode.trim(),
        'shippingProvider': shippingProvider.trim(),
        if (expectedDeliveryAt != null && expectedDeliveryAt.trim().isNotEmpty)
          'expectedDeliveryAt': expectedDeliveryAt.trim(),
      },
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> confirmCod(
    String token,
    String orderCode, {
    String? note,
  }) async {
    final response = await _dio.post(
      '/api/orders/admin/$orderCode/confirm-cod',
      options: _auth(token),
      queryParameters: {
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
    return _extractMap(response.data);
  }

  Future<AdminPageResult> getReturns(
    String token, {
    int page = 0,
    int size = 10,
    String? keyword,
    String? status,
  }) async {
    final response = await _dio.get(
      '/api/admin/returns',
      options: _auth(token),
      queryParameters: {
        'page': page,
        'size': size,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return _extractPage(response.data);
  }

  Future<Map<String, dynamic>> getReturnStats(String token) async {
    final response = await _dio.get(
      '/api/admin/returns/stats',
      options: _auth(token),
    );
    return _extractMap(response.data);
  }

  Future<AdminPageResult> getUsers(
    String token, {
    int page = 0,
    int size = 10,
    String? keyword,
    String? role,
    bool? active,
  }) async {
    final response = await _dio.get(
      '/api/users/admin',
      options: _auth(token),
      queryParameters: {
        'page': page,
        'size': size,
        if (keyword != null && keyword.isNotEmpty) 'keyword': keyword,
        if (role != null && role.isNotEmpty) 'role': role,
        if (active != null) 'active': active,
      },
    );
    return _extractPage(response.data);
  }

  Future<AdminPageResult> getPromotions(
    String token, {
    int page = 0,
    int size = 10,
    bool? activeOnly,
  }) async {
    final response = await _dio.get(
      '/api/promotions',
      options: _auth(token),
      queryParameters: {
        'page': page,
        'size': size,
        if (activeOnly != null) 'activeOnly': activeOnly,
      },
    );
    return _extractPage(response.data);
  }

  Future<List<Map<String, dynamic>>> getLowStock(
    String token, {
    int threshold = 10,
  }) async {
    final response = await _dio.get(
      '/api/inventory/admin/low-stock',
      options: _auth(token),
      queryParameters: {'threshold': threshold},
    );
    return _extractList(response.data);
  }

  Future<AdminPageResult> getAdminChatInbox(
    String token, {
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/chat/admin/inbox',
      options: _auth(token),
      queryParameters: {'page': page, 'size': size},
    );
    return _extractPage(response.data);
  }

  Future<void> reindexSearch(String token) async {
    await _dio.post('/api/search/products/reindex', options: _auth(token));
  }

  Future<AdminPageResult> getProductsAdmin(
    String token, {
    int page = 0,
    int size = 20,
    String? keyword,
    String? category,
    String? brand,
    double? minPrice,
    double? maxPrice,
    bool? isActive,
    bool? isDeleted,
    String? sortBy,
    String? sortDir,
  }) async {
    final hasKeyword = keyword != null && keyword.trim().isNotEmpty;
    final endpoint = hasKeyword ? '/api/search/products' : '/api/products/admin';
    final queryParams = <String, dynamic>{
      'page': page,
      'size': size,
      if (hasKeyword) 'keyword': keyword.trim(),
      if (category != null && category.isNotEmpty) 'category': category,
      if (brand != null && brand.isNotEmpty) 'brand': brand,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (sortBy != null && sortBy.isNotEmpty) 'sortBy': sortBy,
      if (sortDir != null && sortDir.isNotEmpty) 'sortDir': sortDir,
    };

    if (hasKeyword) {
      if (isActive != null) {
        queryParams['activeOnly'] = isActive;
      }
    } else {
      if (isActive != null) queryParams['isActive'] = isActive;
      if (isDeleted != null) queryParams['isDeleted'] = isDeleted;
    }

    final response = await _dio.get(
      endpoint,
      options: _auth(token),
      queryParameters: queryParams,
    );
    
    // DEBUG LOG
    // ignore: avoid_print
    print('>>> API SEARCH RAW RESPONSE is list: ${response.data is List}');
    // ignore: avoid_print
    print('>>> API SEARCH RAW RESPONSE: ${response.data}');

    return _extractPage(response.data);
  }

  Future<List<Map<String, dynamic>>> getBrands(String token) async {
    final response = await _dio.get('/api/brands', options: _auth(token));
    return _extractList(response.data);
  }

  Future<List<Map<String, dynamic>>> getCategories(String token) async {
    final response = await _dio.get('/api/categories', options: _auth(token));
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> createProduct(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/api/products',
      options: _auth(token),
      data: payload,
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> updateProduct(
    String token,
    String productId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put(
      '/api/products/$productId',
      options: _auth(token),
      data: payload,
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> updateProductStatus(
    String token,
    String productId, {
    required bool active,
  }) async {
    final response = await _dio.patch(
      '/api/products/$productId/status',
      options: _auth(token),
      queryParameters: {'active': active},
    );
    return _extractMap(response.data);
  }

  Future<void> deleteProduct(String token, String productId) async {
    await _dio.delete('/api/products/$productId', options: _auth(token));
  }

  Future<List<Map<String, dynamic>>> getProductVariants(
    String token,
    String productId,
  ) async {
    final response = await _dio.get(
      '/api/products/$productId/variants',
      options: _auth(token),
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> createProductVariant(
    String token,
    String productId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.post(
      '/api/products/$productId/variants',
      options: _auth(token),
      data: payload,
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> updateProductVariant(
    String token,
    String productId,
    String variantId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put(
      '/api/products/$productId/variants/$variantId',
      options: _auth(token),
      data: payload,
    );
    return _extractMap(response.data);
  }

  Future<void> deleteProductVariant(
    String token,
    String productId,
    String variantId,
  ) async {
    await _dio.delete(
      '/api/products/$productId/variants/$variantId',
      options: _auth(token),
    );
  }

  Future<List<Map<String, dynamic>>> getProductImages(
    String token,
    String productId,
  ) async {
    final response = await _dio.get(
      '/api/products/$productId/images',
      options: _auth(token),
    );
    return _extractList(response.data);
  }

  Future<Map<String, dynamic>> uploadProductImage(
    String token,
    String productId, {
    required String filePath,
    String? color,
    bool isMain = false,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (color != null && color.trim().isNotEmpty) 'color': color.trim(),
      'isMain': isMain,
    });

    final response = await _dio.post(
      '/api/products/$productId/images',
      options: _auth(token),
      data: formData,
    );
    return _extractMap(response.data);
  }

  Future<Map<String, dynamic>> updateProductImage(
    String token,
    String productId,
    String imageId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _dio.put(
      '/api/products/$productId/images/$imageId',
      options: _auth(token),
      data: payload,
    );
    return _extractMap(response.data);
  }

  Future<void> deleteProductImage(
    String token,
    String productId,
    String imageId,
  ) async {
    await _dio.delete(
      '/api/products/$productId/images/$imageId',
      options: _auth(token),
    );
  }

  AdminPageResult _extractPage(dynamic payload) {
    final map = _extractMap(payload);
    final content = map['content'] ?? map['items'] ?? map['data'];

    final list = (content is List)
        ? content.map((e) {
            if (e is Map) {
              return Map<String, dynamic>.from(e);
            }
            return <String, dynamic>{};
          }).where((e) => e.isNotEmpty).toList()
        : <Map<String, dynamic>>[];

    return AdminPageResult(
      items: list,
      page: _toInt(map['number'] ?? map['page'] ?? map['currentPage'] ?? 0),
      size: _toInt(map['size'] ?? 20),
      totalElements: _toInt(map['totalElements'] ?? map['totalItems'] ?? map['total']),
      totalPages: _toInt(map['totalPages'] ?? map['pageCount']),
    );
  }

  List<Map<String, dynamic>> _extractList(dynamic payload) {
    if (payload is List) {
      return payload
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (payload is Map<String, dynamic>) {
      final data = payload['data'];

      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (data is Map<String, dynamic>) {
        if (data['content'] is List) {
          return (data['content'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }

        if (data['items'] is List) {
          return (data['items'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }

    final map = _extractMap(payload);
    if (map.isEmpty) {
      return const <Map<String, dynamic>>[];
    }

    if (map['content'] is List) {
      return (map['content'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (map['items'] is List) {
      return (map['items'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    return const <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _extractMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    }
    return const <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}

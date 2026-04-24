import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class HomeRemoteDataSource {
  HomeRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<CategoryModel>> getAllCategories() async {
    final response = await _dio.get('/api/categories');
    return _parseList(
      response.data,
    ).map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<List<ProductModel>> getFeaturedProducts({int limit = 8}) async {
    final response = await _dio.get(
      '/api/products/featured',
      queryParameters: {'limit': limit},
    );
    return _parseList(
      response.data,
    ).map((e) => ProductModel.fromJson({...e, 'isFeatured': true})).toList();
  }

  Future<List<ProductModel>> getNewestProducts({int limit = 8}) async {
    final response = await _dio.get(
      '/api/products/new',
      queryParameters: {'limit': limit},
    );
    return _parseList(
      response.data,
    ).map((e) => ProductModel.fromJson({...e, 'isNew': true})).toList();
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
}

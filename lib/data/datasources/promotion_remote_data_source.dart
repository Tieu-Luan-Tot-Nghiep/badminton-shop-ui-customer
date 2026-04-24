import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../models/promotion_model.dart';

class PromotionRemoteDataSource {
  PromotionRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<PromotionModel>> getActivePromotions() async {
    final response = await _dio.get(
      '/api/promotions',
      queryParameters: {
        'page': 0,
        'size': 20,
        'activeOnly': true,
      },
    );

    return _extractPromotions(response.data);
  }

  List<PromotionModel> _extractPromotions(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      
      if (data is Map<String, dynamic>) {
        final content = data['content'] ?? data['items'];
        if (content is List) {
          return content
              .whereType<Map>()
              .map((e) => PromotionModel.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }
    }
    
    return const [];
  }
}

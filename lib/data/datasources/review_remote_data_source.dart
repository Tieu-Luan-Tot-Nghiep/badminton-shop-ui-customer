import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/review_model.dart';

class ReviewRemoteDataSource {
  ReviewRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<ReviewModel>> getMyReviews(String token, {int page = 0, int size = 10}) async {
    final response = await _dio.get(
      '/api/reviews/my',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    final payload = response.data;
    final map = _pickEnvelope(payload);
    final list = _extractContent(map) ?? _extractContent(payload) ?? const [];
    
    return list.map(ReviewModel.fromJson).toList();
  }

  Future<void> updateReview(String token, String id, double rating, String comment) async {
    await _dio.put(
      '/api/reviews/$id',
      data: {'rating': rating, 'comment': comment},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> deleteReview(String token, String id) async {
    await _dio.delete(
      '/api/reviews/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
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

  List<Map<String, dynamic>>? _extractContent(dynamic payload) {
    if (payload is List) return payload.whereType<Map<String, dynamic>>().toList();
    if (payload is Map<String, dynamic>) {
      final content = payload['content'] ?? payload['items'] ?? payload['data'];
      if (content is List) return content.whereType<Map<String, dynamic>>().toList();
    }
    return null;
  }
}

import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/membership_model.dart';

class MembershipRemoteDataSource {
  MembershipRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<MembershipModel> getMyMembership(String token) async {
    final response = await _dio.get(
      '/api/memberships/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    return MembershipModel.fromJson(_pickEnvelope(response.data));
  }

  Future<List<MembershipHistoryModel>> getMyHistory(String token) async {
    final response = await _dio.get(
      '/api/memberships/me/history',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final payload = response.data;
    final data = _pickEnvelope(payload);
    final list = _extractContent(data) ?? _extractContent(payload) ?? const [];
    return list.map(MembershipHistoryModel.fromJson).toList();
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
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic>) {
      final content = payload['content'] ?? payload['items'] ?? payload['data'];
      if (content is List) {
        return content.whereType<Map<String, dynamic>>().toList();
      }
    }
    return null;
  }
}

import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/order_model.dart';
import '../models/checkout_model.dart';

class OrderRemoteDataSource {
  OrderRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<OrderModel>> getMyOrders(
    String token, {
    int page = 0,
    int size = 10,
  }) async {
    final response = await _dio.get(
      '/api/orders/my',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final payload = response.data;
    final map = _pickEnvelope(payload);
    final list = _extractContent(map) ?? _extractContent(payload) ?? const [];

    return list.map(OrderModel.fromJson).toList();
  }

  Future<void> cancelOrder(
    String token,
    String orderCode,
    String reason,
  ) async {
    await _dio.post(
      '/api/orders/$orderCode/cancel',
      data: {'reason': reason},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> createReturnRequest(
    String token,
    String orderCode,
    Map<String, dynamic> payload,
  ) async {
    await _dio.post(
      '/api/orders/$orderCode/returns',
      data: payload,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<OrderPreviewResponse> previewOrder(
    String token,
    CreateOrderRequest request,
  ) async {
    final response = await _dio.post(
      '/api/orders/preview',
      data: request.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return OrderPreviewResponse.fromJson(_pickEnvelope(response.data));
  }

  Future<OrderModel> purchase(String token, CreateOrderRequest request) async {
    final response = await _dio.post(
      '/api/orders',
      data: request.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return OrderModel.fromJson(_pickEnvelope(response.data));
  }

  Future<Map<String, dynamic>> vnpayReturn(
    Map<String, String> queryParameters,
  ) async {
    final response = await _dio.get(
      '/api/orders/vnpay-return',
      queryParameters: queryParameters,
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    }

    return const {};
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

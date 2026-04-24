import '../entities/order_entity.dart';
import '../../data/models/checkout_model.dart';

abstract class OrderRepository {
  Future<List<OrderEntity>> getMyOrders(
    String token, {
    int page = 0,
    int size = 10,
  });
  Future<void> cancelOrder(String token, String orderCode, String reason);
  Future<OrderPreviewResponse> previewOrder(
    String token,
    CreateOrderRequest request,
  );
  Future<OrderEntity> purchase(String token, CreateOrderRequest request);
  Future<Map<String, dynamic>> vnpayReturn(Map<String, String> queryParameters);
}

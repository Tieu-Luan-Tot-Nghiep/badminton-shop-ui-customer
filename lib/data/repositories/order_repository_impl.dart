import '../../data/models/checkout_model.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';

class OrderRepositoryImpl implements OrderRepository {
  OrderRepositoryImpl(this._remote);

  final OrderRemoteDataSource _remote;

  @override
  Future<List<OrderEntity>> getMyOrders(
    String token, {
    int page = 0,
    int size = 10,
  }) async {
    final models = await _remote.getMyOrders(token, page: page, size: size);
    return models.map((e) => e.toEntity()).toList();
  }

  @override
  Future<void> cancelOrder(String token, String orderCode, String reason) {
    return _remote.cancelOrder(token, orderCode, reason);
  }

  @override
  Future<OrderPreviewResponse> previewOrder(
    String token,
    CreateOrderRequest request,
  ) {
    return _remote.previewOrder(token, request);
  }

  @override
  Future<OrderEntity> purchase(String token, CreateOrderRequest request) async {
    final model = await _remote.purchase(token, request);
    return model.toEntity();
  }

  @override
  Future<Map<String, dynamic>> vnpayReturn(
    Map<String, String> queryParameters,
  ) {
    return _remote.vnpayReturn(queryParameters);
  }
}

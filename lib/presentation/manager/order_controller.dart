import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../../data/models/checkout_model.dart';
import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/order_repository.dart';
import 'auth_controller.dart';

class OrderController extends ChangeNotifier {
  OrderController(this._repository, this._authController);

  final OrderRepository _repository;
  final AuthController _authController;

  List<OrderEntity> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Checkout state
  bool _isPlacing = false;
  String? _placeError;
  OrderEntity? _lastPlacedOrder;

  List<OrderEntity> get orders => _orders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPlacing => _isPlacing;
  String? get placeError => _placeError;
  OrderEntity? get lastPlacedOrder => _lastPlacedOrder;

  String? get _token => _authController.session?.token;

  Future<void> loadOrders() async {
    final token = _token;
    if (token == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _repository.getMyOrders(token);
    } catch (e) {
      _errorMessage = 'Không thể tải lịch sử đơn hàng.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelOrder(String orderCode, String reason) async {
    final token = _token;
    if (token == null) return false;

    try {
      await _repository.cancelOrder(token, orderCode, reason);
      await loadOrders();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể hủy đơn hàng.';
      return false;
    }
  }

  Future<bool> createReturnRequest(
    String orderCode,
    Map<String, dynamic> payload,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) return false;

    try {
      await _repository.createReturnRequest(token, orderCode, payload);
      await loadOrders();
      return true;
    } catch (e) {
      _errorMessage = _toReadablePlaceError(e);
      notifyListeners();
      return false;
    }
  }

  Future<OrderPreviewResponse?> previewOrder(CreateOrderRequest request) async {
    final token = _token;
    if (token == null) return null;
    try {
      return await _repository.previewOrder(token, request);
    } catch (_) {
      return null;
    }
  }

  Future<bool> placeOrder(CreateOrderRequest request) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _placeError = 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      notifyListeners();
      return false;
    }

    _isPlacing = true;
    _placeError = null;
    notifyListeners();

    try {
      _lastPlacedOrder = await _repository.purchase(token, request);
      return true;
    } catch (e) {
      _placeError = _toReadablePlaceError(e);
      if (kDebugMode) {
        debugPrint('[OrderController][placeOrder] error=$e');
      }
      return false;
    } finally {
      _isPlacing = false;
      notifyListeners();
    }
  }

  String _toReadablePlaceError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final body = error.response?.data;

      final message = _extractBackendMessage(body);
      if (message != null && message.isNotEmpty) {
        return message;
      }

      if (status == 400) {
        return 'Đơn hàng không hợp lệ. Vui lòng kiểm tra lại sản phẩm, địa chỉ hoặc voucher.';
      }
      if (status == 401) {
        return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
      }
      if (status == 403) {
        return 'Bạn không có quyền thực hiện thao tác này.';
      }
      if (status == 404) {
        return 'Không tìm thấy dữ liệu đơn hàng hoặc sản phẩm.';
      }
      if (status == 409) {
        return 'Không thể đặt hàng do xung đột dữ liệu. Vui lòng thử lại.';
      }
      if (status == 500) {
        return 'Máy chủ đang bận. Vui lòng thử lại sau.';
      }
    }

    return 'Không thể đặt hàng. Vui lòng thử lại.';
  }

  String? _extractBackendMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      const keys = ['message', 'error', 'detail', 'description', 'msg'];

      for (final key in keys) {
        final value = body[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }

      final data = body['data'];
      if (data is Map<String, dynamic>) {
        for (final key in keys) {
          final value = data[key];
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }
    }

    if (body is String && body.trim().isNotEmpty) {
      return body.trim();
    }

    return null;
  }

  Future<Map<String, dynamic>?> completeVnpayPaymentFromCallbackUrl(
    String callbackUrl,
  ) async {
    try {
      final uri = Uri.parse(callbackUrl);
      final query = <String, String>{};
      uri.queryParameters.forEach((key, value) {
        if (key.startsWith('vnp_') ||
            key == 'orderCode' ||
            key == 'paymentStatus' ||
            key == 'orderStatus' ||
            key == 'responseCode') {
          query[key] = value;
        }
      });

      if (query.isEmpty) {
        return null;
      }

      return await _repository.vnpayReturn(query);
    } catch (_) {
      return null;
    }
  }
}

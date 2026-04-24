import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../data/datasources/cart_remote_data_source.dart';
import 'auth_controller.dart';

class CartController extends ChangeNotifier {
  CartController(this._remote, this._authController);

  final CartRemoteDataSource _remote;
  final AuthController _authController;

  bool isLoading = false;
  String? error;
  String? debugErrorDetails;
  CartSnapshotModel? snapshot;
  final Set<int> _busyVariantIds = <int>{};

  List<CartItemModel> get items => snapshot?.items ?? const [];
  int get totalQuantity => snapshot?.totalQuantity ?? 0;
  double get itemsAmount => snapshot?.itemsAmount ?? 0;
  double get discountAmount => snapshot?.discountAmount ?? 0;
  double get totalAmount => snapshot?.totalAmount ?? 0;

  bool isVariantBusy(int variantId) => _busyVariantIds.contains(variantId);

  Future<void> load() async {
    if (!_authController.isAuthenticated) {
      error = 'Vui long dang nhap de xem gio hang.';
      snapshot = null;
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    debugErrorDetails = null;
    notifyListeners();

    try {
      snapshot = await _runWithAuthRetry(
        (token) => _remote.getMyCart(accessToken: token),
      );
    } catch (e) {
      error = _toReadableError(e);
      debugErrorDetails = _toDebugDetails(e);
      _logDebug('load', e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> increase(CartItemModel item) async {
    await _updateQuantity(item, item.quantity + 1);
  }

  Future<void> decrease(CartItemModel item) async {
    if (item.quantity <= 1) {
      await remove(item);
      return;
    }
    await _updateQuantity(item, item.quantity - 1);
  }

  Future<void> remove(CartItemModel item) async {
    await _runItemMutation(item.variantId, () async {
      snapshot = await _runWithAuthRetry(
        (token) =>
            _remote.removeItem(variantId: item.variantId, accessToken: token),
      );
    });
  }

  Future<void> clearCart() async {
    if (!_authController.isAuthenticated) {
      return;
    }

    isLoading = true;
    error = null;
    debugErrorDetails = null;
    notifyListeners();

    try {
      snapshot = await _runWithAuthRetry(
        (token) => _remote.clearCart(accessToken: token),
      );
    } catch (e) {
      error = _toReadableError(e);
      debugErrorDetails = _toDebugDetails(e);
      _logDebug('clearCart', e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateQuantity(CartItemModel item, int quantity) async {
    await _runItemMutation(item.variantId, () async {
      snapshot = await _runWithAuthRetry(
        (token) => _remote.updateItemQuantity(
          variantId: item.variantId,
          quantity: quantity,
          accessToken: token,
        ),
      );
    });
  }

  Future<void> _runItemMutation(
    int variantId,
    Future<void> Function() action,
  ) async {
    if (!_authController.isAuthenticated) {
      error = 'Vui long dang nhap de cap nhat gio hang.';
      notifyListeners();
      return;
    }

    _busyVariantIds.add(variantId);
    error = null;
    debugErrorDetails = null;
    notifyListeners();

    try {
      await action();
    } catch (e) {
      error = _toReadableError(e);
      debugErrorDetails = _toDebugDetails(e);
      _logDebug('itemMutation:$variantId', e);
    } finally {
      _busyVariantIds.remove(variantId);
      notifyListeners();
    }
  }

  Future<T> _runWithAuthRetry<T>(Future<T> Function(String token) call) async {
    var token = _authController.session?.token;
    if (token == null || token.isEmpty) {
      throw StateError('Missing access token');
    }

    try {
      return await call(token);
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode != 401) {
        rethrow;
      }

      await _authController.refreshToken();
      token = _authController.session?.token;
      if (token == null || token.isEmpty) {
        rethrow;
      }

      return call(token);
    }
  }

  String _toReadableError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status == 401) {
        return 'Phien dang nhap het han. Vui long dang nhap lai.';
      }
      if (status == 404) {
        return 'San pham khong ton tai trong gio hang.';
      }
      if (status == 400) {
        return 'Du lieu cap nhat gio hang khong hop le.';
      }
      return 'Khong the dong bo gio hang voi may chu (HTTP ${status ?? 'N/A'}).';
    }

    final text = error.toString();
    if (text.contains('Missing access token')) {
      return 'Khong tim thay token dang nhap hop le.';
    }
    return 'Khong the dong bo gio hang voi may chu.';
  }

  String _toDebugDetails(Object error) {
    if (error is! DioException) {
      return error.toString();
    }

    final req = error.requestOptions;
    final status = error.response?.statusCode;
    final responseData = error.response?.data;

    return [
      'request: ${req.method} ${req.baseUrl}${req.path}',
      'query: ${req.queryParameters}',
      'data: ${req.data}',
      'status: ${status ?? 'N/A'}',
      'response: ${responseData ?? 'null'}',
    ].join('\n');
  }

  void _logDebug(String action, Object error) {
    final detail = _toDebugDetails(error);
    debugPrint('[CartController][$action] $detail');
  }
}

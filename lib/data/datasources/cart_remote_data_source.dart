import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';

class CartRemoteDataSource {
  CartRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<CartSnapshotModel> getMyCart({required String accessToken}) async {
    final response = await _dio.get(
      '/api/cart',
      options: _authOptions(accessToken),
    );
    return CartSnapshotModel.fromPayload(response.data);
  }

  Future<CartSnapshotModel> addItem({
    required int variantId,
    required int quantity,
    required String accessToken,
  }) async {
    final response = await _dio.post(
      '/api/cart/items',
      data: {'variantId': variantId, 'quantity': quantity},
      options: _authOptions(accessToken),
    );
    return CartSnapshotModel.fromPayload(response.data);
  }

  Future<CartSnapshotModel> updateItemQuantity({
    required int variantId,
    required int quantity,
    required String accessToken,
  }) async {
    final response = await _dio.put(
      '/api/cart/items/$variantId',
      data: {'quantity': quantity},
      options: _authOptions(accessToken),
    );
    return CartSnapshotModel.fromPayload(response.data);
  }

  Future<CartSnapshotModel> removeItem({
    required int variantId,
    required String accessToken,
  }) async {
    final response = await _dio.delete(
      '/api/cart/items/$variantId',
      options: _authOptions(accessToken),
    );
    return CartSnapshotModel.fromPayload(response.data);
  }

  Future<CartSnapshotModel> clearCart({required String accessToken}) async {
    final response = await _dio.delete(
      '/api/cart',
      options: _authOptions(accessToken),
    );
    return CartSnapshotModel.fromPayload(response.data);
  }

  Options _authOptions(String accessToken) {
    return Options(headers: {'Authorization': 'Bearer $accessToken'});
  }
}

class CartSnapshotModel {
  const CartSnapshotModel({
    required this.items,
    required this.itemsAmount,
    required this.discountAmount,
    required this.totalAmount,
  });

  final List<CartItemModel> items;
  final double itemsAmount;
  final double discountAmount;
  final double totalAmount;

  int get totalQuantity =>
      items.fold<int>(0, (sum, item) => sum + item.quantity);

  factory CartSnapshotModel.fromPayload(dynamic payload) {
    final map = _pickEnvelope(payload);
    final itemRows = _extractItems(map) ?? _extractItems(payload) ?? const [];
    final items = itemRows.map(CartItemModel.fromJson).toList();

    final computedItemsAmount = items.fold<double>(
      0,
      (sum, item) => sum + item.lineTotal,
    );

    final itemsAmount = _toDouble(
      map['itemsAmount'] ??
          map['subTotal'] ??
          map['subtotal'] ??
          computedItemsAmount,
    );
    final totalAmount = _toDouble(
      map['totalAmount'] ?? map['total'] ?? map['grandTotal'] ?? itemsAmount,
    );

    var discountAmount = _toDouble(
      map['discountAmount'] ?? map['discount'] ?? (itemsAmount - totalAmount),
    );
    if (discountAmount < 0) {
      discountAmount = 0;
    }

    return CartSnapshotModel(
      items: items,
      itemsAmount: itemsAmount,
      discountAmount: discountAmount,
      totalAmount: totalAmount,
    );
  }
}

class CartItemModel {
  const CartItemModel({
    required this.variantId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.lineTotal,
    this.imageUrl,
    this.size,
    this.color,
    this.stock,
    this.tag,
  });

  final int variantId;
  final String productId;
  final String productName;
  final int quantity;
  final double price;
  final double lineTotal;
  final String? imageUrl;
  final String? size;
  final String? color;
  final int? stock;
  final String? tag;

  String get specText {
    final values = <String>[];
    if ((color ?? '').trim().isNotEmpty) {
      values.add((color ?? '').trim().toUpperCase());
    }
    if ((size ?? '').trim().isNotEmpty) {
      values.add((size ?? '').trim().toUpperCase());
    }
    return values.join(' | ');
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final variant = _toMap(json['variant']);
    final product = _toMap(json['product']);

    final quantity = _toInt(json['quantity'] ?? json['qty'] ?? 1);
    final price = _toDouble(
      json['price'] ??
          json['unitPrice'] ??
          variant['price'] ??
          product['basePrice'] ??
          0,
    );

    return CartItemModel(
      variantId: _toInt(
        json['variantId'] ??
            json['productVariantId'] ??
            variant['id'] ??
            json['id'],
      ),
      productId: '${json['productId'] ?? product['id'] ?? ''}',
      productName:
          '${json['productName'] ?? product['name'] ?? json['name'] ?? 'UNKNOWN PRODUCT'}',
      quantity: quantity,
      price: price,
      lineTotal: _toDouble(
        json['lineTotal'] ??
            json['subtotal'] ??
            json['amount'] ??
            price * quantity,
      ),
      imageUrl:
          json['thumbnailUrl']?.toString() ??
          json['imageUrl']?.toString() ??
          variant['imageUrl']?.toString() ??
          product['thumbnailUrl']?.toString() ??
          product['imageUrl']?.toString(),
      size: '${json['size'] ?? variant['size'] ?? ''}',
      color: '${json['color'] ?? variant['color'] ?? ''}',
      stock: _toNullableInt(json['stock'] ?? variant['stock']),
      tag: json['tag']?.toString() ?? variant['tag']?.toString(),
    );
  }
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

List<Map<String, dynamic>>? _extractItems(dynamic payload) {
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  if (payload is! Map<String, dynamic>) {
    return null;
  }

  const keys = ['items', 'cartItems', 'content', 'records', 'list', 'data'];
  for (final key in keys) {
    final value = payload[key];
    if (value is List) {
      return value.whereType<Map<String, dynamic>>().toList();
    }
    if (value is Map<String, dynamic>) {
      final nested = _extractItems(value);
      if (nested != null) {
        return nested;
      }
    }
  }

  return null;
}

Map<String, dynamic> _toMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  return const {};
}

double _toDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse('$value') ?? 0;
}

int _toInt(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}

int? _toNullableInt(dynamic value) {
  final parsed = _toInt(value);
  if (parsed <= 0) {
    return null;
  }
  return parsed;
}

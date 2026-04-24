import '../../domain/entities/order_entity.dart';

class OrderModel {
  const OrderModel({
    required this.orderCode,
    required this.orderStatus,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.totalAmount,
    required this.createdAt,
    this.paymentUrl,
    this.items = const [],
  });

  final String orderCode;
  final String orderStatus;
  final String paymentStatus;
  final String paymentMethod;
  final double totalAmount;
  final DateTime createdAt;
  final String? paymentUrl;
  final List<OrderItemModel> items;

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['orderItems'] ?? json['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map<String, dynamic>>()
              .map(OrderItemModel.fromJson)
              .toList()
        : const <OrderItemModel>[];

    return OrderModel(
      orderCode: '${json['orderCode'] ?? ''}',
      orderStatus: '${json['orderStatus'] ?? ''}',
      paymentStatus: '${json['paymentStatus'] ?? ''}',
      paymentMethod: '${json['paymentMethod'] ?? ''}',
      totalAmount: _toDouble(json['totalAmount'] ?? 0),
      createdAt: _parseDate(json['createdAt']),
      paymentUrl: _toNullableString(json['paymentUrl']),
      items: items,
    );
  }

  OrderEntity toEntity() {
    return OrderEntity(
      orderCode: orderCode,
      orderStatus: orderStatus,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      totalAmount: totalAmount,
      createdAt: createdAt,
      paymentUrl: paymentUrl,
      items: items.map((e) => e.toEntity()).toList(),
    );
  }

  static double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
  static String? _toNullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static DateTime _parseDate(dynamic v) {
    if (v == null) return DateTime.now();
    return DateTime.tryParse('$v') ?? DateTime.now();
  }
}

class OrderItemModel {
  const OrderItemModel({
    required this.id,
    required this.productName,
    required this.variantName,
    required this.thumbnailUrl,
    required this.price,
    required this.quantity,
  });

  final int id;
  final String productName;
  final String variantName;
  final String thumbnailUrl;
  final double price;
  final int quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: _toInt(json['id']),
      productName: '${json['productName'] ?? ''}',
      variantName: '${json['variantName'] ?? ''}',
      thumbnailUrl: '${json['thumbnailUrl'] ?? json['imageUrl'] ?? ''}',
      price: _toDouble(json['price'] ?? 0),
      quantity: _toInt(json['quantity'] ?? 0),
    );
  }

  OrderItemEntity toEntity() {
    return OrderItemEntity(
      id: id,
      productName: productName,
      variantName: variantName,
      thumbnailUrl: thumbnailUrl,
      price: price,
      quantity: quantity,
    );
  }

  static double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
  static int _toInt(dynamic v) =>
      (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);
}

class OrderEntity {
  const OrderEntity({
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
  final List<OrderItemEntity> items;
}

class OrderItemEntity {
  const OrderItemEntity({
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
}

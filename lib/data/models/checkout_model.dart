class CreateOrderRequest {
  const CreateOrderRequest({
    required this.items,
    this.addressId,
    this.voucherCode,
    this.orderNote,
    required this.paymentMethod,
    this.status,
    this.receiverName,
    this.receiverPhone,
    this.shippingAddress,
  });

  final List<CreateOrderItemRequest> items;
  final int? addressId;
  final String? voucherCode;
  final String? orderNote;
  final String paymentMethod;
  final String? status;
  final String? receiverName;
  final String? receiverPhone;
  final String? shippingAddress;

  Map<String, dynamic> toJson() {
    return {
      'items': items.map((e) => e.toJson()).toList(),
      if (addressId != null) 'addressId': addressId,
      if (voucherCode != null) 'voucherCode': voucherCode,
      if (orderNote != null) 'orderNote': orderNote,
      'paymentMethod': paymentMethod,
      if (status != null) 'status': status,
      if (receiverName != null) 'receiverName': receiverName,
      if (receiverPhone != null) 'receiverPhone': receiverPhone,
      if (shippingAddress != null) 'shippingAddress': shippingAddress,
    };
  }
}

class CreateOrderItemRequest {
  const CreateOrderItemRequest({
    required this.variantId,
    required this.quantity,
  });

  final int variantId;
  final int quantity;

  Map<String, dynamic> toJson() {
    return {'variantId': variantId, 'quantity': quantity};
  }
}

class OrderPreviewResponse {
  const OrderPreviewResponse({
    required this.itemsAmount,
    required this.shippingFee,
    required this.discountAmount,
    required this.totalAmount,
    this.addressId,
    this.voucherCode,
  });

  final double itemsAmount;
  final double shippingFee;
  final double discountAmount;
  final double totalAmount;
  final int? addressId;
  final String? voucherCode;

  factory OrderPreviewResponse.fromJson(Map<String, dynamic> json) {
    return OrderPreviewResponse(
      itemsAmount: _toDouble(json['itemsAmount'] ?? 0),
      shippingFee: _toDouble(json['shippingFee'] ?? 0),
      discountAmount: _toDouble(json['discountAmount'] ?? 0),
      totalAmount: _toDouble(json['totalAmount'] ?? 0),
      addressId: json['addressId'] as int?,
      voucherCode: json['voucherCode'] as String?,
    );
  }

  static double _toDouble(dynamic v) =>
      (v is num) ? v.toDouble() : (double.tryParse('$v') ?? 0);
}

import '../../domain/entities/promotion_entity.dart';

class PromotionModel extends PromotionEntity {
  const PromotionModel({
    required super.id,
    required super.code,
    required super.discountType,
    required super.discountValue,
    required super.minOrderValue,
    required super.maxDiscountAmount,
    required super.maxUsage,
    required super.currentUsage,
    required super.startDate,
    required super.expiryDate,
    required super.isActive,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      id: _toInt(json['id']),
      code: '${json['code'] ?? ''}',
      discountType: '${json['discountType'] ?? 'PERCENTAGE'}',
      discountValue: _toDouble(json['discountValue']),
      minOrderValue: _toDouble(json['minOrderValue']),
      maxDiscountAmount: _toDouble(json['maxDiscountAmount']),
      maxUsage: _toInt(json['maxUsage']),
      currentUsage: _toInt(json['currentUsage']),
      startDate: json['startDate'] != null
          ? DateTime.tryParse('${json['startDate']}')
          : null,
      expiryDate: json['expiryDate'] != null
          ? DateTime.tryParse('${json['expiryDate']}')
          : null,
      isActive: json['isActive'] == true || '${json['isActive']}' == 'true',
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }
}

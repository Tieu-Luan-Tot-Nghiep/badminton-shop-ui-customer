class PromotionEntity {
  const PromotionEntity({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minOrderValue,
    required this.maxDiscountAmount,
    required this.maxUsage,
    required this.currentUsage,
    required this.startDate,
    required this.expiryDate,
    required this.isActive,
  });

  final int id;
  final String code;
  final String discountType; // 'PERCENTAGE', 'FIXED_AMOUNT', 'FREE_SHIP'
  final double discountValue;
  final double minOrderValue;
  final double maxDiscountAmount;
  final int maxUsage;
  final int currentUsage;
  final DateTime? startDate;
  final DateTime? expiryDate;
  final bool isActive;
}

class MembershipTierEntity {
  const MembershipTierEntity({
    required this.id,
    required this.name,
    required this.minPoints,
    required this.discountPercent,
    required this.benefits,
  });

  final int id;
  final String name;
  final int minPoints;
  final double discountPercent;
  final String benefits;
}

class MembershipEntity {
  const MembershipEntity({
    required this.userId,
    required this.email,
    required this.tier,
    required this.currentPoints,
    required this.totalPoints,
    required this.pointsToNextTier,
    required this.nextTierName,
  });

  final int userId;
  final String email;
  final MembershipTierEntity tier;
  final int currentPoints;
  final int totalPoints;
  final int pointsToNextTier;
  final String? nextTierName;
}

class MembershipHistoryEntity {
  const MembershipHistoryEntity({
    required this.id,
    required this.points,
    required this.reason,
    required this.referenceId,
    required this.createdAt,
  });

  final int id;
  final int points;
  final String reason;
  final int? referenceId;
  final DateTime createdAt;
}

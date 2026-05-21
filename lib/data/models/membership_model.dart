import '../../domain/entities/membership_entity.dart';

class MembershipTierModel {
  const MembershipTierModel({
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

  factory MembershipTierModel.fromJson(Map<String, dynamic> json) {
    return MembershipTierModel(
      id: _toInt(json['id']),
      name: '${json['name'] ?? ''}',
      minPoints: _toInt(json['minPoints']),
      discountPercent: _toDouble(json['discountPercent']),
      benefits: '${json['benefits'] ?? ''}',
    );
  }

  MembershipTierEntity toEntity() => MembershipTierEntity(
    id: id,
    name: name,
    minPoints: minPoints,
    discountPercent: discountPercent,
    benefits: benefits,
  );
}

class MembershipModel {
  const MembershipModel({
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
  final MembershipTierModel tier;
  final int currentPoints;
  final int totalPoints;
  final int pointsToNextTier;
  final String? nextTierName;

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      userId: _toInt(json['userId']),
      email: '${json['email'] ?? ''}',
      tier: MembershipTierModel.fromJson(
        (json['tier'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
      currentPoints: _toInt(json['currentPoints']),
      totalPoints: _toInt(json['totalPoints']),
      pointsToNextTier: _toInt(json['pointsToNextTier']),
      nextTierName: json['nextTierName']?.toString(),
    );
  }

  MembershipEntity toEntity() => MembershipEntity(
    userId: userId,
    email: email,
    tier: tier.toEntity(),
    currentPoints: currentPoints,
    totalPoints: totalPoints,
    pointsToNextTier: pointsToNextTier,
    nextTierName: nextTierName,
  );
}

class MembershipHistoryModel {
  const MembershipHistoryModel({
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

  factory MembershipHistoryModel.fromJson(Map<String, dynamic> json) {
    return MembershipHistoryModel(
      id: _toInt(json['id']),
      points: _toInt(json['points']),
      reason: '${json['reason'] ?? ''}',
      referenceId: _toNullableInt(json['referenceId']),
      createdAt: _parseDate(json['createdAt']),
    );
  }

  MembershipHistoryEntity toEntity() => MembershipHistoryEntity(
    id: id,
    points: points,
    reason: reason,
    referenceId: referenceId,
    createdAt: createdAt,
  );
}

int _toInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

int? _toNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value') ?? 0;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse('$value') ?? DateTime.now();
}

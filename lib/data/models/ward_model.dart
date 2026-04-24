import '../../domain/entities/ward_entity.dart';

class WardModel {
  const WardModel({
    required this.wardCode,
    required this.wardName,
    required this.districtId,
  });

  final String wardCode;
  final String wardName;
  final int districtId;

  factory WardModel.fromJson(Map<String, dynamic> json) {
    return WardModel(
      wardCode: json['wardCode'] as String,
      wardName: json['wardName'] as String,
      districtId: json['districtId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'wardCode': wardCode,
      'wardName': wardName,
      'districtId': districtId,
    };
  }

  WardEntity toEntity() {
    return WardEntity(
      wardCode: wardCode,
      wardName: wardName,
      districtId: districtId,
    );
  }

  factory WardModel.fromEntity(WardEntity entity) {
    return WardModel(
      wardCode: entity.wardCode,
      wardName: entity.wardName,
      districtId: entity.districtId,
    );
  }
}

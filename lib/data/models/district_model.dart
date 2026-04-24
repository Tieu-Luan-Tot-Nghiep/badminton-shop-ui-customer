import '../../domain/entities/district_entity.dart';

class DistrictModel {
  const DistrictModel({
    required this.districtId,
    required this.districtName,
    required this.provinceId,
  });

  final int districtId;
  final String districtName;
  final int provinceId;

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      districtId: json['districtId'] as int,
      districtName: json['districtName'] as String,
      provinceId: json['provinceId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'districtId': districtId,
      'districtName': districtName,
      'provinceId': provinceId,
    };
  }

  DistrictEntity toEntity() {
    return DistrictEntity(
      districtId: districtId,
      districtName: districtName,
      provinceId: provinceId,
    );
  }

  factory DistrictModel.fromEntity(DistrictEntity entity) {
    return DistrictModel(
      districtId: entity.districtId,
      districtName: entity.districtName,
      provinceId: entity.provinceId,
    );
  }
}

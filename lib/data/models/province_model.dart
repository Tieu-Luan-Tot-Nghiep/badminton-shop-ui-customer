import '../../domain/entities/province_entity.dart';

class ProvinceModel {
  const ProvinceModel({
    required this.provinceId,
    required this.provinceName,
  });

  final int provinceId;
  final String provinceName;

  factory ProvinceModel.fromJson(Map<String, dynamic> json) {
    return ProvinceModel(
      provinceId: json['provinceId'] as int,
      provinceName: json['provinceName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provinceId': provinceId,
      'provinceName': provinceName,
    };
  }

  ProvinceEntity toEntity() {
    return ProvinceEntity(
      provinceId: provinceId,
      provinceName: provinceName,
    );
  }

  factory ProvinceModel.fromEntity(ProvinceEntity entity) {
    return ProvinceModel(
      provinceId: entity.provinceId,
      provinceName: entity.provinceName,
    );
  }
}

import '../../domain/entities/address_entity.dart';

class AddressModel {
  const AddressModel({
    required this.id,
    required this.receiverName,
    required this.phoneNumber,
    required this.province,
    required this.district,
    required this.ward,
    required this.specificAddress,
    this.ghnProvinceId,
    this.ghnDistrictId,
    this.ghnWardCode,
    this.isDefault = false,
  });

  final int id;
  final String receiverName;
  final String phoneNumber;
  final String province;
  final String district;
  final String ward;
  final String specificAddress;
  final int? ghnProvinceId;
  final int? ghnDistrictId;
  final String? ghnWardCode;
  final bool isDefault;

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: _toInt(json['id']),
      receiverName: '${json['receiverName'] ?? ''}',
      phoneNumber: '${json['phoneNumber'] ?? ''}',
      province: '${json['province'] ?? ''}',
      district: '${json['district'] ?? ''}',
      ward: '${json['ward'] ?? ''}',
      specificAddress: '${json['specificAddress'] ?? ''}',
      ghnProvinceId: _toIntOrNull(json['ghnProvinceId']),
      ghnDistrictId: _toIntOrNull(json['ghnDistrictId']),
      ghnWardCode: json['ghnWardCode']?.toString(),
      isDefault: json['isDefault'] == true,
    );
  }

  factory AddressModel.fromEntity(AddressEntity entity) {
    return AddressModel(
      id: entity.id,
      receiverName: entity.receiverName,
      phoneNumber: entity.phoneNumber,
      province: entity.province,
      district: entity.district,
      ward: entity.ward,
      specificAddress: entity.specificAddress,
      ghnProvinceId: entity.ghnProvinceId,
      ghnDistrictId: entity.ghnDistrictId,
      ghnWardCode: entity.ghnWardCode,
      isDefault: entity.isDefault,
    );
  }

  AddressEntity toEntity() {
    return AddressEntity(
      id: id,
      receiverName: receiverName,
      phoneNumber: phoneNumber,
      province: province,
      district: district,
      ward: ward,
      specificAddress: specificAddress,
      ghnProvinceId: ghnProvinceId,
      ghnDistrictId: ghnDistrictId,
      ghnWardCode: ghnWardCode,
      isDefault: isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'receiverName': receiverName,
      'phoneNumber': phoneNumber,
      'province': province,
      'district': district,
      'ward': ward,
      'specificAddress': specificAddress,
      'isDefault': isDefault,
    };
  }

  static int _toInt(dynamic v) => (v is num) ? v.toInt() : (int.tryParse('$v') ?? 0);
  static int? _toIntOrNull(dynamic v) => (v != null) ? _toInt(v) : null;
}

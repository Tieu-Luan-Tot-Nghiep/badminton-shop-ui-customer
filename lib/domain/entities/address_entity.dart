class AddressEntity {
  const AddressEntity({
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
}

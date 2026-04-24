class DistrictEntity {
  const DistrictEntity({
    required this.districtId,
    required this.districtName,
    required this.provinceId,
  });

  final int districtId;
  final String districtName;
  final int provinceId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DistrictEntity &&
          runtimeType == other.runtimeType &&
          districtId == other.districtId;

  @override
  int get hashCode => districtId.hashCode;
}

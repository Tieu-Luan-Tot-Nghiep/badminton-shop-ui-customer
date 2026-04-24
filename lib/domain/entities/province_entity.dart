class ProvinceEntity {
  const ProvinceEntity({
    required this.provinceId,
    required this.provinceName,
  });

  final int provinceId;
  final String provinceName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProvinceEntity &&
          runtimeType == other.runtimeType &&
          provinceId == other.provinceId;

  @override
  int get hashCode => provinceId.hashCode;
}

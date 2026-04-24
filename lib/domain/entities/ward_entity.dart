class WardEntity {
  const WardEntity({
    required this.wardCode,
    required this.wardName,
    required this.districtId,
  });

  final String wardCode;
  final String wardName;
  final int districtId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WardEntity &&
          runtimeType == other.runtimeType &&
          wardCode == other.wardCode;

  @override
  int get hashCode => wardCode.hashCode;
}

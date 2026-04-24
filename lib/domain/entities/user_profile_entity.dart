class UserProfileEntity {
  const UserProfileEntity({
    required this.id,
    this.fullName,
    required this.email,
    this.phoneNumber,
    this.birthDate,
    this.avatar,
    this.role,
  });

  final String id;
  final String? fullName;
  final String email;
  final String? phoneNumber;
  final String? birthDate;
  final String? avatar;
  final String? role;
}

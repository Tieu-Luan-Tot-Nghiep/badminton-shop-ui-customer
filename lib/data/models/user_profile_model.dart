import '../../domain/entities/user_profile_entity.dart';

class UserProfileModel {
  const UserProfileModel({
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

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: '${json['id'] ?? ''}',
      fullName: json['fullName']?.toString(),
      email: '${json['email'] ?? ''}',
      phoneNumber: json['phoneNumber']?.toString(),
      birthDate: json['birthDate']?.toString(),
      avatar: json['avatar']?.toString(),
      role: json['role']?.toString(),
    );
  }

  UserProfileEntity toEntity() {
    return UserProfileEntity(
      id: id,
      fullName: fullName,
      email: email,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
      avatar: avatar,
      role: role,
    );
  }
}

class AuthSessionEntity {
  const AuthSessionEntity({
    required this.token,
    this.refreshToken,
    this.username,
    this.role,
  });

  final String token;
  final String? refreshToken;
  final String? username;
  final String? role;
}

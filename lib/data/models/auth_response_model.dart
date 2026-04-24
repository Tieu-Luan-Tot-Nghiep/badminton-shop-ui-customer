import '../../domain/entities/auth_session_entity.dart';

class AuthResponseModel {
  const AuthResponseModel({
    required this.token,
    this.refreshToken,
    this.username,
    this.role,
  });

  final String token;
  final String? refreshToken;
  final String? username;
  final String? role;

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    final envelope = _pickEnvelope(json);

    final token = _readString(envelope, const [
      'token',
      'accessToken',
      'access_token',
      'jwt',
      'id_token',
    ]);
    final refreshToken = _readString(envelope, const [
      'refreshToken',
      'refresh_token',
    ]);
    final username =
        _readString(envelope, const ['username', 'userName', 'name']) ??
        _readString(
          _nestedMap(envelope, const ['user', 'account', 'profile']),
          const ['username', 'userName', 'name'],
        );
    final role =
        _readString(envelope, const ['role', 'authority']) ??
        _readString(
          _nestedMap(envelope, const ['user', 'account', 'profile']),
          const ['role', 'authority'],
        );

    return AuthResponseModel(
      token: token ?? '',
      refreshToken: refreshToken,
      username: username,
      role: role,
    );
  }

  AuthSessionEntity toEntity() {
    return AuthSessionEntity(
      token: token,
      refreshToken: refreshToken,
      username: username,
      role: role,
    );
  }

  static Map<String, dynamic> _pickEnvelope(Map<String, dynamic> json) {
    final candidates = [
      _nestedMap(json, const ['data', 'result', 'payload']),
      json,
    ];

    for (final map in candidates) {
      if (map == null) {
        continue;
      }
      final token = _readString(map, const [
        'token',
        'accessToken',
        'access_token',
        'jwt',
        'id_token',
      ]);
      if (token != null && token.isNotEmpty) {
        return map;
      }
    }
    return candidates.firstWhere((m) => m != null, orElse: () => json) ?? json;
  }

  static Map<String, dynamic>? _nestedMap(
    Map<String, dynamic>? source,
    List<String> keys,
  ) {
    if (source == null) {
      return null;
    }

    for (final key in keys) {
      final value = source[key];
      if (value is Map<String, dynamic>) {
        return value;
      }
    }
    return null;
  }

  static String? _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) {
      return null;
    }

    for (final key in keys) {
      final value = map[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return null;
  }
}

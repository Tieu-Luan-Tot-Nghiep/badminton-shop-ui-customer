import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/network/api_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_profile_model.dart';

class AuthRemoteDataSource {
  AuthRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;
  static const String callbackScheme = 'shuttlex';

  Future<AuthResponseModel> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    String? email,
    String? uid,
    String? displayName,
  }) async {
    final normalizedProvider = provider.trim().toLowerCase();

    if (normalizedProvider == 'google') {
      if (idToken == null || idToken.trim().isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/auth/google/login'),
          error: 'idToken is required',
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/api/auth/google/login'),
            statusCode: 400,
            data: const {
              'message': 'idToken: idToken is required',
              'status': 'error',
              'statusCode': 400,
              'data': null,
            },
          ),
        );
      }

      final response = await _dio.post(
        '/api/auth/google/login',
        data: {'idToken': idToken.trim()},
      );

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return AuthResponseModel.fromJson(data);
      }

      throw DioException(
        requestOptions: response.requestOptions,
        error: 'Unexpected google login response payload',
        type: DioExceptionType.badResponse,
        response: response,
      );
    }

    return _socialLoginViaOAuthRedirect(provider: normalizedProvider);
  }

  Future<AuthResponseModel> _socialLoginViaOAuthRedirect({
    required String provider,
  }) async {
    final base = Uri.parse(_dio.options.baseUrl);
    final authUri = Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '/oauth2/authorization/$provider',
    );

    final callbackUrl = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: callbackScheme,
      options: const FlutterWebAuth2Options(preferEphemeral: true),
    );

    final uri = Uri.parse(callbackUrl);
    final query = uri.queryParameters;
    final fragment = _parseFragment(uri.fragment);

    final token =
        query['token'] ??
        query['accessToken'] ??
        fragment['token'] ??
        fragment['accessToken'];
    final refreshToken = query['refreshToken'] ?? fragment['refreshToken'];
    final username = query['username'] ?? fragment['username'];
    final role = query['role'] ?? fragment['role'];

    if (token == null || token.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: authUri.toString()),
        error: 'OAuth callback does not include access token.',
        type: DioExceptionType.badResponse,
      );
    }

    return AuthResponseModel(
      token: token,
      refreshToken: refreshToken,
      username: username,
      role: role,
    );
  }

  Map<String, String> _parseFragment(String fragment) {
    if (fragment.isEmpty) {
      return const {};
    }

    return Uri.splitQueryString(fragment);
  }

  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    await _dio.post(
      '/api/auth/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'phoneNumber': phoneNumber,
      },
    );
  }

  Future<AuthResponseModel> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      return AuthResponseModel.fromJson(payload);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      error: 'Unexpected login response payload',
      type: DioExceptionType.badResponse,
      response: response,
    );
  }

  Future<AuthResponseModel> refresh({required String refreshToken}) async {
    final response = await _dio.post(
      '/api/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final payload = response.data;
    if (payload is Map<String, dynamic>) {
      return AuthResponseModel.fromJson(payload);
    }

    throw DioException(
      requestOptions: response.requestOptions,
      error: 'Unexpected refresh response payload',
      type: DioExceptionType.badResponse,
      response: response,
    );
  }

  Future<void> verifyEmail({
    required String token,
    required String email,
  }) async {
    await _dio.get(
      '/api/auth/verify-email',
      queryParameters: {'token': token, 'email': email},
    );
  }

  Future<void> resendVerification({required String email}) async {
    await _dio.post('/api/auth/resend-verification', data: {'email': email});
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post('/api/auth/forgot-password', data: {'email': email});
  }

  Future<UserProfileModel> getCurrentUser(String token) async {
    final response = await _dio.get(
      '/api/auth/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return UserProfileModel.fromJson(_pickEnvelope(response.data));
  }

  Future<void> updateProfile({
    required String token,
    required String fullName,
    required String phoneNumber,
    String? birthDate,
  }) async {
    await _dio.put(
      '/api/auth/profile',
      data: {
        'fullName': fullName,
        'phoneNumber': phoneNumber,
        if (birthDate != null) 'birthDate': birthDate,
      },
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> updateAvatar({
    required String token,
    required String imagePath,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
    });

    await _dio.post(
      '/api/auth/profile/avatar',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post(
      '/api/auth/change-password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Map<String, dynamic> _pickEnvelope(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    }
    return const {};
  }
}

import 'dart:async';

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient._();

  static String? Function()? _getAccessToken;
  static Future<String?> Function()? _refreshAccessToken;
  static Completer<String?>? _refreshCompleter;

  static final Dio instance =
      Dio(
          BaseOptions(
            baseUrl: const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'https://shuttlex.io.vn',
            ),
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(seconds: 30),
            sendTimeout: const Duration(seconds: 30),
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              final header = options.headers['Authorization'];
              final token = _getAccessToken?.call();

              if (header == null && token != null && token.isNotEmpty) {
                options.headers['Authorization'] = 'Bearer $token';
              }

              handler.next(options);
            },
            onError: (error, handler) async {
              final statusCode = error.response?.statusCode;
              final request = error.requestOptions;
              final hasRetried = request.extra['authRetried'] == true;
              final authHeader =
                  request.headers['Authorization']?.toString() ?? '';
              final isBearer = authHeader.startsWith('Bearer ');

              final path = request.path;
              final isAuthEndpoint =
                  path.contains('/api/auth/login') ||
                  path.contains('/api/auth/refresh') ||
                  path.contains('/api/auth/register');

              if (statusCode != 401 ||
                  hasRetried ||
                  !isBearer ||
                  isAuthEndpoint) {
                handler.next(error);
                return;
              }

              final newToken = await _refreshTokenSafely();
              if (newToken == null || newToken.isEmpty) {
                handler.next(error);
                return;
              }

              request.headers['Authorization'] = 'Bearer $newToken';
              request.extra['authRetried'] = true;

              try {
                final response = await instance.fetch<dynamic>(request);
                handler.resolve(response);
              } catch (_) {
                handler.next(error);
              }
            },
          ),
        );

  static void configureAuth({
    required String? Function() getAccessToken,
    required Future<String?> Function() refreshAccessToken,
  }) {
    _getAccessToken = getAccessToken;
    _refreshAccessToken = refreshAccessToken;
  }

  static Future<String?> _refreshTokenSafely() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refresher = _refreshAccessToken;
      if (refresher == null) {
        completer.complete(null);
      } else {
        final token = await refresher();
        completer.complete(token);
      }
    } catch (_) {
      completer.complete(null);
    } finally {
      _refreshCompleter = null;
    }

    return completer.future;
  }
}

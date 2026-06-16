import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Xử lý toàn bộ vòng đời FCM:
///   1. Xin quyền notification
///   2. Lấy FCM token
///   3. Lắng nghe tin nhắn foreground/background/terminated
///
/// Cách dùng:
///   final fcm = FcmService();
///   await fcm.initialize(onTokenRefresh: (token) => apiClient.updateFcmToken(token));
///   fcm.onMessageTap = (data) => navigateTo(data['screen']);
class FcmService {
  FcmService._();

  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Callback khi người dùng tap vào notification → data payload từ message
  ValueChanged<Map<String, dynamic>>? onMessageTap;

  /// Callback khi nhận tin nhắn lúc app đang foreground
  ValueChanged<RemoteMessage>? onForegroundMessage;

  /// Khởi tạo FCM, xin quyền, lắng nghe token refresh và message
  Future<void> initialize({
    required Future<void> Function(String token) onTokenRefresh,
  }) async {
    // 1. Xin quyền trên iOS / Android 13+
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Quyền notification bị từ chối');
      return;
    }

    // 2. Lấy token ban đầu và đẩy lên server
    final token = await getToken();
    if (token != null) {
      await _safeCall(() => onTokenRefresh(token));
    }

    // 3. Theo dõi token thay đổi (reset thiết bị, xoá data, ...)
    _messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('[FCM] Token mới: ${newToken.substring(0, 10)}...');
      await _safeCall(() => onTokenRefresh(newToken));
    });

    // 4. Tin nhắn khi app đang mở (foreground)
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      onForegroundMessage?.call(message);
    });

    // 5. Người dùng tap notification khi app đang background (nhưng chưa terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessageTap(message);
    });

    // 6. App được mở từ terminated state do tap notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
  }

  /// Lấy FCM token hiện tại của thiết bị
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('[FCM] Lỗi lấy token: $e');
      return null;
    }
  }

  void _handleMessageTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('[FCM] Người dùng tap notification. screen=${data['screen']}, orderCode=${data['orderCode']}');
    if (onMessageTap != null && data.isNotEmpty) {
      onMessageTap!(data);
    }
  }

  Future<void> _safeCall(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      debugPrint('[FCM] Lỗi callback: $e');
    }
  }
}

/// Background message handler — PHẢI là top-level function (không phải method)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM Background] ${message.notification?.title}: ${message.notification?.body}');
}

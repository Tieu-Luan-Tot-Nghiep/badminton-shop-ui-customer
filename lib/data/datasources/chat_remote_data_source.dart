import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/errors/app_exception.dart';
import '../../core/network/api_client.dart';
import '../models/chat_model.dart';

class ChatRemoteDataSource {
  ChatRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;
  StompClient? _stompClient;

  void Function(ChatMessageModel message)? onMessageReceived;
  void Function(String roomId)? onRoomRead;
  void Function(int messageId)? onMessageSent;
  
  void connectStomp(String accessToken, String roomId) {
    if (_stompClient != null && _stompClient!.isActive) return;

    final baseUrl = _dio.options.baseUrl.isNotEmpty ? _dio.options.baseUrl : 'http://localhost:8080';
    // Convert http/https to ws/wss
    String wsUrl = baseUrl.replaceFirst('http', 'ws');
    if (!wsUrl.endsWith('/')) {
      wsUrl += '/';
    }
    wsUrl += 'ws-chat/websocket';

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: (frame) => _onStompConnected(frame, roomId),
        beforeConnect: () async {
          debugPrint('Connecting to STOMP at $wsUrl');
        },
        onWebSocketError: (dynamic error) => debugPrint('STOMP WS Error: $error'),
        stompConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
        webSocketConnectHeaders: {
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );

    _stompClient!.activate();
  }

  void _onStompConnected(StompFrame frame, String roomId) {
    debugPrint('STOMP Connected successfully!');
    
    _stompClient!.subscribe(
      destination: '/topic/chat.room.$roomId',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!);
            final message = ChatMessageModel.fromJson(json);
            onMessageReceived?.call(message);
          } catch (e) {
            debugPrint('Error parsing chat message: $e');
          }
        }
      },
    );

    _stompClient!.subscribe(
      destination: '/topic/chat.room.$roomId.read',
      callback: (frame) {
        onRoomRead?.call(roomId);
      },
    );

    _stompClient!.subscribe(
      destination: '/user/queue/chat.sent',
      callback: (frame) {
        if (frame.body != null) {
          try {
            final json = jsonDecode(frame.body!);
            if (json['id'] != null) {
              onMessageSent?.call(_toIntSafe(json['id']));
            }
          } catch (e) {
            debugPrint('Error parsing message from STOMP chat.sent: $e');
          }
        }
      },
    );
  }

  void disconnectStomp() {
    _stompClient?.deactivate();
    _stompClient = null;
  }

  void sendMessageOverStomp(ChatSendMessageRequest request) {
    if (_stompClient == null || !_stompClient!.isActive) {
      throw const AppException('Chat not connected. Cannot send message via STOMP.');
    }
    
    _stompClient!.send(
      destination: '/app/chat.send',
      body: jsonEncode(request.toJson()),
    );
  }

  void markRoomReadOverStomp(String roomId) {
    if (_stompClient != null && _stompClient!.isActive) {
      _stompClient!.send(
        destination: '/app/chat.read',
        body: jsonEncode({'roomId': roomId}),
      );
    }
  }

  Future<ChatRoomModel> getOrCreateMyRoom(String token) async {
    final response = await _dio.get(
      '/api/chat/rooms/me',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return ChatRoomModel.fromJson(_pickEnvelope(response.data));
  }

  Future<ChatUnreadCountResponse> getMyUnreadCount(String token) async {
    try {
      final response = await _dio.get(
        '/api/chat/unread-count',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return ChatUnreadCountResponse.fromJson(_pickEnvelope(response.data));
    } catch (_) {
      return ChatUnreadCountResponse(unreadCount: 0);
    }
  }

  Future<List<ChatMessageModel>> getRoomMessages({
    required String roomId,
    required String token,
    int page = 0,
    int size = 20,
  }) async {
    final response = await _dio.get(
      '/api/chat/rooms/$roomId/messages',
      queryParameters: {'page': page, 'size': size},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final payload = response.data;
    final map = _pickEnvelope(payload);
    
    final content = map['content'] ?? map['items'] ?? map['data'];
    if (content is List) {
      return content.whereType<Map<String, dynamic>>()
             .map(ChatMessageModel.fromJson)
             .toList();
    }
    return [];
  }

  Future<void> markRoomAsRead(String roomId, String token) async {
    await _dio.post(
      '/api/chat/rooms/$roomId/read',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<List<ChatUploadResponse>> uploadFiles(List<String> filePaths, String token) async {
    if (filePaths.isEmpty) return [];

    final formData = FormData();
    for (int i = 0; i < filePaths.length; i++) {
        formData.files.add(MapEntry(
            'files', 
            await MultipartFile.fromFile(filePaths[i])
        ));
    }

    final response = await _dio.post(
      '/api/chat/upload',
      data: formData,
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );

    final responseData = response.data;
    List<dynamic>? list;

    if (responseData is List) {
      list = responseData;
    } else if (responseData is Map<String, dynamic>) {
      final innerData = responseData['data'];
      if (innerData is List) {
        list = innerData;
      } else if (innerData is Map<String, dynamic> && innerData['data'] is List) {
        list = innerData['data'] as List;
      }
    }

    if (list != null) {
      return list.whereType<Map<String, dynamic>>()
          .map(ChatUploadResponse.fromJson)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> _pickEnvelope(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload.containsKey('data') && payload['data'] is Map<String, dynamic>) {
        return payload['data'];
      }
      return payload;
    }
    return {};
  }

  int _toIntSafe(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}

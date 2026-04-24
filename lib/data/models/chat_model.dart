import '../../domain/entities/chat_entity.dart';

class ChatRoomModel extends ChatRoomEntity {
  const ChatRoomModel({
    required super.id,
    required super.customerId,
    super.unreadCount = 0,
    required super.updatedAt,
  });

  factory ChatRoomModel.fromJson(Map<String, dynamic> json) {
    return ChatRoomModel(
      id: '${json['id'] ?? json['roomId'] ?? ''}',
      customerId: '${json['customerId'] ?? ''}',
      unreadCount: _toIntSafe(json['unreadCount']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }
}

class ChatMessageModel extends ChatMessageEntity {
  const ChatMessageModel({
    required super.id,
    required super.roomId,
    required super.senderRole,
    required super.messageType,
    super.content = '',
    super.fileUrl,
    super.fileName,
    required super.createdAt,
    super.isRead = false,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: _toIntSafe(json['id']),
      roomId: '${json['roomId'] ?? ''}',
      senderRole: '${json['senderRole'] ?? 'USER'}',
      messageType: '${json['messageType'] ?? 'TEXT'}',
      content: '${json['content'] ?? ''}',
      fileUrl: json['fileUrl']?.toString(),
      fileName: json['fileName']?.toString(),
      createdAt: _parseDate(json['createdAt']),
      isRead: json['isRead'] == true || json['read'] == true,
    );
  }
}

class ChatUnreadCountResponse {
  final int unreadCount;
  ChatUnreadCountResponse({required this.unreadCount});

  factory ChatUnreadCountResponse.fromJson(Map<String, dynamic> json) {
    return ChatUnreadCountResponse(
      unreadCount: _toIntSafe(json['unreadCount'] ?? json['count']),
    );
  }
}

class ChatUploadResponse {
  final String fileUrl;
  final String fileName;
  
  ChatUploadResponse({required this.fileUrl, required this.fileName});

  factory ChatUploadResponse.fromJson(Map<String, dynamic> json) {
    return ChatUploadResponse(
      fileUrl: '${json['fileUrl'] ?? ''}',
      fileName: '${json['fileName'] ?? ''}',
    );
  }
}

class ChatSendMessageRequest {
  final String roomId;
  final String messageType; 
  final String content;
  final String? fileUrl;
  final String? fileName;

  ChatSendMessageRequest({
    required this.roomId,
    required this.messageType,
    required this.content,
    this.fileUrl,
    this.fileName,
  });

  Map<String, dynamic> toJson() {
    return {
      'roomId': roomId,
      'messageType': messageType,
      'content': content,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
    };
  }
}

int _toIntSafe(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  return DateTime.tryParse('$value') ?? DateTime.now();
}

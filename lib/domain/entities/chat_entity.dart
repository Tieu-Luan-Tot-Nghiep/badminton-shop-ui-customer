class ChatRoomEntity {
  const ChatRoomEntity({
    required this.id,
    required this.customerId,
    this.unreadCount = 0,
    required this.updatedAt,
  });

  final String id;
  final String customerId;
  final int unreadCount;
  final DateTime updatedAt;
}

class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.roomId,
    required this.senderRole,
    required this.messageType,
    this.content = '',
    this.fileUrl,
    this.fileName,
    required this.createdAt,
    this.isRead = false,
  });

  final int id;
  final String roomId;
  final String senderRole; // USER, ADMIN
  final String messageType; // TEXT, IMAGE, FILE
  final String content;
  final String? fileUrl;
  final String? fileName;
  final DateTime createdAt;
  final bool isRead;

  bool get isMine => senderRole == 'USER';
}

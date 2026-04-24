import 'package:flutter/foundation.dart';
import '../../data/datasources/chat_remote_data_source.dart';
import '../../data/models/chat_model.dart';
import 'auth_controller.dart';

class ChatController extends ChangeNotifier {
  ChatController(this._authController, {ChatRemoteDataSource? remote})
      : _remote = remote ?? ChatRemoteDataSource() {
    _authController.addListener(_onAuthChanged);
    _remote.onMessageReceived = _handleNewMessage;
    _remote.onRoomRead = _handleRoomRead;
    _remote.onMessageSent = _handleMessageSent;
    _onAuthChanged(); // init check
  }

  final AuthController _authController;
  final ChatRemoteDataSource _remote;

  ChatRoomModel? _currentRoom;
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _unreadCount = 0;
  int _currentPage = 0;
  bool _hasMore = true;

  ChatRoomModel? get currentRoom => _currentRoom;
  List<ChatMessageModel> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  int get unreadCount => _unreadCount;
  bool get hasMore => _hasMore;

  @override
  void dispose() {
    _authController.removeListener(_onAuthChanged);
    _remote.disconnectStomp();
    super.dispose();
  }

  void _onAuthChanged() {
    final token = _authController.session?.token;
    if (token != null && token.isNotEmpty) {
      if (_currentRoom == null) {
        _initChat(token);
      }
    } else {
      _disconnectChat();
    }
  }

  Future<void> _initChat(String token) async {
    try {
      _currentRoom = await _remote.getOrCreateMyRoom(token);
      final unreadResp = await _remote.getMyUnreadCount(token);
      _unreadCount = unreadResp.unreadCount;
      notifyListeners();

      _remote.connectStomp(token, _currentRoom!.id);
      await loadInitialMessages();
    } catch (e) {
      _errorMessage = 'Không thể kết nối chat';
      notifyListeners();
      debugPrint('Chat init error: $e');
    }
  }

  void _disconnectChat() {
    _remote.disconnectStomp();
    _currentRoom = null;
    _messages.clear();
    _unreadCount = 0;
    _currentPage = 0;
    _hasMore = true;
    notifyListeners();
  }

  void _handleNewMessage(ChatMessageModel message) {
    if (_currentRoom == null || message.roomId != _currentRoom!.id) return;

    final index = _messages.indexWhere((m) => m.id == message.id && m.id != 0);
    if (index >= 0) {
      _messages[index] = message;
    } else {
      _messages.insert(0, message);
      if (message.senderRole != 'USER') {
        _unreadCount++;
      }
    }
    notifyListeners();
  }

  void _handleRoomRead(String roomId) {
    if (_currentRoom?.id == roomId) {
      for (var i = 0; i < _messages.length; i++) {
        _messages[i] = ChatMessageModel(
          id: _messages[i].id,
          roomId: _messages[i].roomId,
          senderRole: _messages[i].senderRole,
          messageType: _messages[i].messageType,
          content: _messages[i].content,
          fileUrl: _messages[i].fileUrl,
          fileName: _messages[i].fileName,
          createdAt: _messages[i].createdAt,
          isRead: true,
        );
      }
      notifyListeners();
    }
  }

  void _handleMessageSent(int messageId) {
    // optional ack logic
  }

  Future<void> loadInitialMessages() async {
    final token = _authController.session?.token;
    if (token == null || _currentRoom == null) return;
    
    _isLoading = true;
    _errorMessage = null;
    _currentPage = 0;
    notifyListeners();

    try {
      final list = await _remote.getRoomMessages(roomId: _currentRoom!.id, token: token, page: 0, size: 20);
      _messages.clear();
      _messages.addAll(list.reversed);
      _hasMore = list.length >= 20;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Không thể tải lịch sử chat';
      notifyListeners();
    }
  }

  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMore) return;

    final token = _authController.session?.token;
    if (token == null || _currentRoom == null) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final nextPage = _currentPage + 1;
      final list = await _remote.getRoomMessages(roomId: _currentRoom!.id, token: token, page: nextPage, size: 20);
      if (list.isNotEmpty) {
        _messages.addAll(list.reversed);
        _currentPage = nextPage;
        _hasMore = list.length >= 20;
      } else {
        _hasMore = false;
      }
      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content, {List<String>? imagePaths}) async {
    final token = _authController.session?.token;
    if (token == null || _currentRoom == null) return;

    try {
      if (imagePaths != null && imagePaths.isNotEmpty) {
        final uploads = await _remote.uploadFiles(imagePaths, token);
        for (var upload in uploads) {
          final req = ChatSendMessageRequest(
            roomId: _currentRoom!.id,
            messageType: 'IMAGE',
            content: content.isNotEmpty ? content : 'Sent an image',
            fileUrl: upload.fileUrl,
            fileName: upload.fileName,
          );
          _remote.sendMessageOverStomp(req);
          content = ''; // Only send text caption with the first image
        }
      } else if (content.trim().isNotEmpty) {
        final req = ChatSendMessageRequest(
          roomId: _currentRoom!.id,
          messageType: 'TEXT',
          content: content.trim(),
        );
        _remote.sendMessageOverStomp(req);
      }
    } catch (e) {
      debugPrint('Failed to send message: $e');
    }
  }

  void markAsRead() {
    final token = _authController.session?.token;
    if (token == null || _currentRoom == null || _unreadCount == 0) return;

    _unreadCount = 0;
    notifyListeners();
    try {
      _remote.markRoomAsRead(_currentRoom!.id, token);
      _remote.markRoomReadOverStomp(_currentRoom!.id);
    } catch (_) {}
  }
}

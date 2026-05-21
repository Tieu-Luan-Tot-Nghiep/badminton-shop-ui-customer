import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_client.dart';
import '../../data/models/chat_model.dart';
import '../../presentation/manager/auth_controller.dart';

class AdminChatConversationPage extends StatefulWidget {
  const AdminChatConversationPage({
    super.key,
    required this.authController,
    required this.room,
  });

  final AuthController authController;
  final Map<String, dynamic> room;

  @override
  State<AdminChatConversationPage> createState() =>
      _AdminChatConversationPageState();
}

class _AdminChatConversationPageState
    extends State<AdminChatConversationPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final Dio _dio = ApiClient.instance;

  StompClient? _stompClient;
  final List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isSending = false;
  bool _hasMore = true;
  int _currentPage = 0;
  String? _error;

  String get _roomId =>
      '${widget.room['roomId'] ?? widget.room['conversationId'] ?? widget.room['id'] ?? ''}'
          .trim();

  String get _customerName {
    final candidates = [
      widget.room['customerName'],
      widget.room['fullName'],
      widget.room['name'],
      widget.room['customerEmail'],
      widget.room['email'],
    ];
    for (final c in candidates) {
      final t = '$c'.trim();
      if (t.isNotEmpty && t.toLowerCase() != 'null') return t;
    }
    return 'Khách hàng';
  }

  String get _customerEmail {
    final raw =
        '${widget.room['customerEmail'] ?? widget.room['email'] ?? ''}'.trim();
    return raw.isEmpty || raw.toLowerCase() == 'null' ? '' : raw;
  }

  String get _token => widget.authController.session?.token ?? '';

  Options get _authOpts =>
      Options(headers: {'Authorization': 'Bearer $_token'});

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _connectStomp();
    _markAsRead();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─── REST ────────────────────────────────────────────────────────────────

  Future<void> _loadMessages() async {
    if (_token.isEmpty || _roomId.isEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _fetchMessages(page: 0);
      setState(() {
        _messages
          ..clear()
          ..addAll(list.reversed);
        _currentPage = 0;
        _hasMore = list.length >= 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Không thể tải tin nhắn';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _token.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final nextPage = _currentPage + 1;
      final list = await _fetchMessages(page: nextPage);
      setState(() {
        if (list.isNotEmpty) {
          _messages.addAll(list.reversed);
          _currentPage = nextPage;
          _hasMore = list.length >= 20;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<ChatMessageModel>> _fetchMessages({int page = 0}) async {
    final response = await _dio.get(
      '/api/chat/rooms/$_roomId/messages',
      queryParameters: {'page': page, 'size': 20},
      options: _authOpts,
    );
    final payload = response.data;
    Map<String, dynamic> map = {};
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      map = (data is Map<String, dynamic>) ? data : payload;
    }
    final content = map['content'] ?? map['items'] ?? map['data'];
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageModel.fromJson)
          .toList();
    }
    return [];
  }

  Future<void> _markAsRead() async {
    if (_token.isEmpty || _roomId.isEmpty) return;
    try {
      await _dio.post('/api/chat/rooms/$_roomId/read', options: _authOpts);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> _uploadFiles(
      List<String> filePaths) async {
    final formData = FormData();
    for (final path in filePaths) {
      formData.files.add(
          MapEntry('files', await MultipartFile.fromFile(path)));
    }
    final response = await _dio.post(
      '/api/chat/upload',
      data: formData,
      options: _authOpts,
    );
    final raw = response.data;
    List<dynamic>? list;
    if (raw is List) {
      list = raw;
    } else if (raw is Map<String, dynamic>) {
      final d = raw['data'];
      if (d is List) list = d;
    }
    return list?.whereType<Map<String, dynamic>>().toList() ?? [];
  }

  // ─── STOMP ───────────────────────────────────────────────────────────────

  void _connectStomp() {
    if (_token.isEmpty || _roomId.isEmpty) return;

    final baseUrl = _dio.options.baseUrl.isNotEmpty
        ? _dio.options.baseUrl
        : 'http://localhost:8080';
    String wsUrl = baseUrl.replaceFirst('http', 'ws');
    if (!wsUrl.endsWith('/')) wsUrl += '/';
    wsUrl += 'ws-chat/websocket';

    _stompClient = StompClient(
      config: StompConfig(
        url: wsUrl,
        onConnect: _onStompConnected,
        onWebSocketError: (e) => debugPrint('STOMP WS Error: $e'),
        stompConnectHeaders: {'Authorization': 'Bearer $_token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $_token'},
      ),
    );
    _stompClient!.activate();
  }

  void _onStompConnected(StompFrame frame) {
    // Nhận tin nhắn mới trong room
    _stompClient!.subscribe(
      destination: '/topic/chat.room.$_roomId',
      callback: (frame) {
        if (frame.body == null) return;
        try {
          final msg = ChatMessageModel.fromJson(jsonDecode(frame.body!));
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == msg.id && m.id != 0);
            if (idx >= 0) {
              _messages[idx] = msg;
            } else {
              _messages.insert(0, msg);
            }
          });
          // Đánh dấu đã đọc khi nhận tin nhắn mới
          _markAsRead();
          _sendReadOverStomp();
        } catch (e) {
          debugPrint('Error parsing message: $e');
        }
      },
    );

    // Read receipt
    _stompClient!.subscribe(
      destination: '/topic/chat.room.$_roomId.read',
      callback: (frame) {
        setState(() {
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
        });
      },
    );
  }

  void _sendReadOverStomp() {
    if (_stompClient == null || !_stompClient!.isActive) return;
    _stompClient!.send(
      destination: '/app/chat.read',
      body: jsonEncode({'roomId': _roomId}),
    );
  }

  void _sendMessageOverStomp(Map<String, dynamic> payload) {
    if (_stompClient == null || !_stompClient!.isActive) return;
    _stompClient!.send(
      destination: '/app/chat.send',
      body: jsonEncode(payload),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;
    _textController.clear();
    setState(() => _isSending = true);
    try {
      _sendMessageOverStomp({
        'roomId': _roomId,
        'messageType': 'TEXT',
        'content': text,
        'fileUrl': null,
        'fileName': null,
      });
    } catch (e) {
      debugPrint('Send error: $e');
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.primaryContainer),
              title: const Text('Thư viện ảnh',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded,
                  color: AppColors.primaryContainer),
              title: const Text('Máy ảnh',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final file = await _picker.pickImage(source: source, imageQuality: 70);
    if (file == null) return;

    setState(() => _isSending = true);
    try {
      final uploads = await _uploadFiles([file.path]);
      for (final upload in uploads) {
        _sendMessageOverStomp({
          'roomId': _roomId,
          'messageType': 'IMAGE',
          'content': 'Đã gửi ảnh',
          'fileUrl': upload['fileUrl'],
          'fileName': upload['fileName'],
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể gửi ảnh')),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildMessageList()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        border: Border(
            bottom: BorderSide(
                color: AppColors.surfaceContainerHighest, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surfaceContainerHighest,
            child: const Icon(Icons.person_rounded,
                color: AppColors.primaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                if (_customerEmail.isNotEmpty)
                  Text(
                    _customerEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primaryContainer));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: _loadMessages, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Chưa có tin nhắn nào',
            style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(
                  color: AppColors.primaryContainer, strokeWidth: 2),
            ),
          );
        }
        return _buildBubble(_messages[index]);
      },
    );
  }

  Widget _buildBubble(ChatMessageModel msg) {
    // Admin là người gửi (isMine = true khi senderRole là ADMIN)
    final isAdmin = msg.senderRole.toUpperCase() == 'ADMIN';
    final formatter = DateFormat('HH:mm');

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isAdmin) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.surfaceContainerHighest,
              child: const Icon(Icons.person_rounded,
                  size: 16, color: AppColors.primaryContainer),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isAdmin ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (msg.messageType == 'IMAGE' && msg.fileUrl != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.65,
                      maxHeight: 250,
                    ),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.surfaceContainerHighest,
                    ),
                    child: Image.network(
                      msg.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              color: AppColors.textSecondary)),
                    ),
                  )
                else if (msg.content.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isAdmin
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isAdmin ? 18 : 4),
                        bottomRight: Radius.circular(isAdmin ? 4 : 18),
                      ),
                    ),
                    child: Text(
                      msg.content,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isAdmin
                                ? AppColors.onPrimaryContainer
                                : AppColors.textPrimary,
                          ),
                    ),
                  ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatter.format(msg.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                          ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 4),
                      Icon(
                        msg.isRead
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
                        size: 12,
                        color: msg.isRead
                            ? AppColors.primaryContainer
                            : AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryContainer.withOpacity(0.15),
              child: const Icon(Icons.support_agent_rounded,
                  size: 16, color: AppColors.primaryContainer),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDim,
        border: Border(
            top: BorderSide(
                color: AppColors.surfaceContainerHighest, width: 1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Nút gửi ảnh
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.textPrimary),
              onPressed: _isSending ? null : _pickAndSendImage,
            ),
          ),
          const SizedBox(width: 10),
          // Text input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _textController,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Nhập tin nhắn...',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nút gửi
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: _isSending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: AppColors.onPrimaryContainer),
                    onPressed: _sendText,
                  ),
          ),
        ],
      ),
    );
  }
}

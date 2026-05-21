import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';
import 'admin_chat_conversation_page.dart';

class AdminChatInboxPage extends StatefulWidget {
  const AdminChatInboxPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminChatInboxPage> createState() => _AdminChatInboxPageState();
}

class _AdminChatInboxPageState extends State<AdminChatInboxPage> {
  final TextEditingController _searchController = TextEditingController();
  late Future<AdminPageResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadInbox();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminPageResult> _loadInbox() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }
    return widget.dataSource.getAdminChatInbox(token, size: 50);
  }

  Future<void> _refreshInbox() async {
    setState(() {
      _future = _loadInbox();
    });
    await _future;
  }

  String _roomId(Map<String, dynamic> room) {
    return '${room['roomId'] ?? room['conversationId'] ?? room['id'] ?? ''}'
        .trim();
  }

  String _customerName(Map<String, dynamic> room) {
    final candidates = <dynamic>[
      room['customerName'],
      room['fullName'],
      room['name'],
      room['customerEmail'],
      room['email'],
      room['customerId'],
      room['id'],
    ];
    for (final candidate in candidates) {
      final text = '$candidate'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return 'Khách hàng';
  }

  String _customerEmail(Map<String, dynamic> room) {
    final raw = '${room['customerEmail'] ?? room['email'] ?? ''}'.trim();
    return raw.isEmpty || raw.toLowerCase() == 'null' ? 'Chưa có email' : raw;
  }

  String _lastMessage(Map<String, dynamic> room) {
    final raw = '${room['lastMessagePreview'] ?? ''}'.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return 'Chưa có tin nhắn';
    }
    return raw;
  }

  String _updatedAt(Map<String, dynamic> room) {
    final raw = '${room['updatedAt'] ?? room['lastMessageAt'] ?? ''}'.trim();
    final dt = DateTime.tryParse(raw);
    if (dt == null) return '';
    return DateFormat('HH:mm dd/MM').format(dt.toLocal());
  }

  int _unreadCount(Map<String, dynamic> room) {
    final raw = room['adminUnreadCount'] ?? room['unreadCount'] ?? 0;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 0;
  }

  List<Map<String, dynamic>> _filteredRooms(List<Map<String, dynamic>> items) {
    final keyword = _searchController.text.trim().toLowerCase();
    if (keyword.isEmpty) return items;
    return items.where((room) {
      final haystack = <String>[
        _roomId(room),
        _customerName(room),
        _customerEmail(room),
        _lastMessage(room),
      ].join(' ').toLowerCase();
      return haystack.contains(keyword);
    }).toList();
  }

  void _openConversation(Map<String, dynamic> room) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminChatConversationPage(
          authController: widget.authController,
          room: room,
        ),
      ),
    );
  }

  Widget _buildRoomTile(Map<String, dynamic> room) {
    final unread = _unreadCount(room);
    final name = _customerName(room);
    final email = _customerEmail(room);
    final lastMsg = _lastMessage(room);
    final time = _updatedAt(room);

    return GestureDetector(
      onTap: () => _openConversation(room),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceContainerHighest,
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primaryContainer,
                    size: 26,
                  ),
                ),
                if (unread > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          unread > 9 ? '9+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lastMsg,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            // Header cố định
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  AdminTopBar(
                    title: 'HỘP THƯ CHAT',
                    role: widget.authController.userRole ?? 'ADMIN',
                    onLogout: () => widget.authController.logout(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm khách hàng, email...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // Danh sách cuộn được
            Expanded(
              child: FutureBuilder<AdminPageResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryContainer,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              snapshot.error?.toString() ??
                                  'Không tải được inbox chat',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.redAccent),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _refreshInbox,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allRooms = snapshot.data?.items ?? const [];
                  final rooms = _filteredRooms(allRooms);

                  if (rooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded,
                              size: 56, color: AppColors.textSecondary),
                          const SizedBox(height: 12),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Chưa có cuộc hội thoại nào'
                                : 'Không tìm thấy kết quả',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refreshInbox,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) =>
                          _buildRoomTile(rooms[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

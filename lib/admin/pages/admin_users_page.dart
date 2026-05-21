import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  static const List<String> _roleFilters = <String>['ALL', 'ADMIN', 'CUSTOMER'];
  static const List<String> _statusFilters = <String>[
    'ALL',
    'ACTIVE',
    'INACTIVE',
  ];

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _togglingUserIds = <String>{};
  final Map<String, bool> _activeOverrides = <String, bool>{};

  String _selectedRole = 'ALL';
  String _selectedStatus = 'ALL';
  int _currentPage = 0;
  final int _pageSize = 20;
  int _totalPages = 1;
  int _totalElements = 0;

  late Future<AdminPageResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<AdminPageResult> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final keyword = _searchController.text.trim().isEmpty
        ? null
        : _searchController.text.trim();
    final role = _selectedRole == 'ALL' ? null : _selectedRole;
    final active = _selectedStatus == 'ALL'
        ? null
        : _selectedStatus == 'ACTIVE';

    final result = await widget.dataSource.getUsers(
      token,
      page: _currentPage,
      size: _pageSize,
      keyword: keyword,
      role: role,
      active: active,
    );

    _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
    _totalElements = result.totalElements;
    return result;
  }

  void _reload({int? page}) {
    setState(() {
      if (page != null) {
        _currentPage = page;
      }
      _future = _load();
    });
  }

  bool _isTruthy(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }

    final normalized = '$value'.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y' ||
        normalized == 'active' ||
        normalized == 'enabled' ||
        normalized == 'on';
  }

  bool _isUserActive(Map<String, dynamic> user) {
    final id = '${user['id'] ?? ''}'.trim();
    final local = _activeOverrides[id];
    if (local != null) {
      return local;
    }

    const directKeys = <String>['isActive', 'is_active', 'active', 'enabled'];
    for (final key in directKeys) {
      if (!user.containsKey(key)) {
        continue;
      }

      final raw = user[key];
      if ('$raw'.trim().isEmpty || '$raw'.trim().toLowerCase() == 'null') {
        continue;
      }
      return _isTruthy(raw);
    }

    final status = '${user['status'] ?? ''}'.trim().toLowerCase();
    if (status == 'active' || status == 'enabled') {
      return true;
    }
    if (status == 'inactive' || status == 'disabled' || status == 'deleted') {
      return false;
    }

    return false;
  }

  String _displayName(Map<String, dynamic> user) {
    final candidates = <dynamic>[
      user['fullName'],
      user['username'],
      user['email'],
      user['id'],
    ];
    for (final item in candidates) {
      final text = '$item'.trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return 'N/A';
  }

  String _displayEmail(Map<String, dynamic> user) {
    final value = '${user['email'] ?? ''}'.trim();
    if (value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
    return 'Chưa có email';
  }

  String _displayRole(Map<String, dynamic> user) {
    final role = '${user['role'] ?? 'CUSTOMER'}'.trim();
    return role.isEmpty ? 'CUSTOMER' : role.toUpperCase();
  }

  Future<void> _openUserDetail(Map<String, dynamic> user) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = '${user['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => _UserDetailSheet(
        userId: id,
        token: token,
        dataSource: widget.dataSource,
      ),
    );
  }

  Future<void> _toggleStatus(
    Map<String, dynamic> user, {
    bool? targetActive,
  }) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = '${user['id'] ?? ''}'.trim();
    if (id.isEmpty || _togglingUserIds.contains(id)) {
      return;
    }

    final current = _isUserActive(user);
    final nextValue = targetActive ?? !current;
    final displayName = _displayName(user);

    final approved =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(nextValue ? 'Bật tài khoản' : 'Tắt tài khoản'),
            content: Text(
              'Bạn có chắc muốn ${nextValue ? 'bật' : 'tắt'} tài khoản "$displayName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xác nhận'),
              ),
            ],
          ),
        ) ??
        false;

    if (!approved) {
      return;
    }

    setState(() {
      _activeOverrides[id] = nextValue;
      _togglingUserIds.add(id);
    });

    try {
      await widget.dataSource.updateUserStatus(token, id, active: nextValue);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã cập nhật trạng thái người dùng: ${nextValue ? 'Bật' : 'Tắt'}',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _activeOverrides[id] = current;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Cập nhật trạng thái thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingUserIds.remove(id);
        });
      }
    }
  }

  Future<void> _openUserEditor({Map<String, dynamic>? existing}) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (_) => _UserEditorSheet(
        token: token,
        dataSource: widget.dataSource,
        existing: existing,
      ),
    );

    if (changed == true && mounted) {
      _reload(page: 0);
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = '${user['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    final name = _displayName(user);
    final approved =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xóa người dùng'),
            content: Text('Bạn có chắc muốn xóa tài khoản "$name"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Xóa'),
              ),
            ],
          ),
        ) ??
        false;

    if (!approved) {
      return;
    }

    try {
      await widget.dataSource.deleteUser(token, id);
      if (!mounted) {
        return;
      }
      _reload(page: 0);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa người dùng.')));
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Xóa người dùng thất bại')),
      );
    }
  }

  Future<void> _onUserMenuAction(
    String action,
    Map<String, dynamic> user,
  ) async {
    switch (action) {
      case 'detail':
        await _openUserDetail(user);
        break;
      case 'edit':
        await _openUserEditor(existing: user);
        break;
      case 'toggle':
        await _toggleStatus(user, targetActive: !_isUserActive(user));
        break;
      case 'delete':
        await _deleteUser(user);
        break;
    }
  }

  Widget _filterChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryContainer),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final roleLabel = _selectedRole == 'ALL'
        ? 'Vai trò: Tất cả'
        : 'Vai trò: $_selectedRole';
    final statusLabel = _selectedStatus == 'ALL'
        ? 'Trạng thái: Tất cả'
        : _selectedStatus == 'ACTIVE'
        ? 'Trạng thái: Hoạt động'
        : 'Trạng thái: Ngừng hoạt động';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedRole = value;
              });
              _reload(page: 0);
            },
            itemBuilder: (context) => _roleFilters
                .map(
                  (value) => PopupMenuItem<String>(
                    value: value,
                    child: Text(value == 'ALL' ? 'Tất cả vai trò' : value),
                  ),
                )
                .toList(),
            child: _filterChip(roleLabel, Icons.badge_outlined),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedStatus = value;
              });
              _reload(page: 0);
            },
            itemBuilder: (context) => _statusFilters
                .map(
                  (value) => PopupMenuItem<String>(
                    value: value,
                    child: Text(
                      value == 'ALL'
                          ? 'Tất cả trạng thái'
                          : value == 'ACTIVE'
                          ? 'Hoạt động'
                          : 'Ngừng hoạt động',
                    ),
                  ),
                )
                .toList(),
            child: _filterChip(statusLabel, Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final id = '${user['id'] ?? ''}'.trim();
    final name = _displayName(user);
    final email = _displayEmail(user);
    final role = _displayRole(user);
    final active = _isUserActive(user);
    final isToggling = _togglingUserIds.contains(id);

    return _Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openUserDetail(user),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'ID: $id',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontFamily: 'monospace',
                              ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) => _onUserMenuAction(value, user),
                    itemBuilder: (context) => [
                      const PopupMenuItem<String>(
                        value: 'detail',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.info_outline),
                          title: Text('Chi tiết'),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Sửa'),
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'toggle',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            active
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          title: Text(
                            active ? 'Tắt tài khoản' : 'Bật tài khoản',
                          ),
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          title: Text('Xóa'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Vai trò: $role',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.primaryContainer
                          : AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    active ? 'Đang bật' : 'Đang tắt',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: active,
                    onChanged: id.isEmpty || isToggling
                        ? null
                        : (value) => _toggleStatus(user, targetActive: value),
                    activeThumbColor: AppColors.primaryContainer,
                    activeTrackColor: AppColors.primaryContainer.withValues(
                      alpha: 0.45,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async {
            _reload();
            await _future;
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
            children: [
              AdminTopBar(
                title: 'QUẢN LÝ NGƯỜI DÙNG',
                role: widget.authController.userRole ?? 'ADMIN',
                onLogout: () => widget.authController.logout(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              decoration: const InputDecoration(
                                hintText: 'Tìm theo id, name, username, email',
                                border: InputBorder.none,
                              ),
                              onSubmitted: (_) => _reload(page: 0),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _reload(page: 0),
                            icon: const Icon(Icons.send_rounded),
                            tooltip: 'Tìm kiếm',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildFilterChips(),
              const SizedBox(height: 12),
              FutureBuilder<AdminPageResult>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return _Card(
                      child: Text(
                        snapshot.error?.toString() ??
                            'Không thể tải danh sách người dùng',
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    );
                  }

                  final result = snapshot.data!;
                  if (result.items.isEmpty) {
                    return const _Card(
                      child: Text('Không tìm thấy người dùng nào'),
                    );
                  }

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Tổng: $_totalElements',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...result.items.map(_buildUserCard),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _currentPage > 0
                                ? () => _reload(page: _currentPage - 1)
                                : null,
                            child: const Text('Trước'),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: Text(
                                'Trang ${_currentPage + 1}/$_totalPages',
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton(
                            onPressed: _currentPage + 1 < _totalPages
                                ? () => _reload(page: _currentPage + 1)
                                : null,
                            child: const Text('Sau'),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 22,
          child: FloatingActionButton(
            onPressed: () => _openUserEditor(),
            backgroundColor: AppColors.primaryContainer,
            foregroundColor: AppColors.onPrimaryContainer,
            tooltip: 'Thêm người dùng',
            child: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({this.margin, required this.child});

  final EdgeInsetsGeometry? margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _UserDetailSheet extends StatelessWidget {
  const _UserDetailSheet({
    required this.userId,
    required this.token,
    required this.dataSource,
  });

  final String userId;
  final String token;
  final AdminRemoteDataSource dataSource;

  String _field(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '-',
  }) {
    for (final key in keys) {
      final value = '${data[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return fallback;
  }

  String _boolText(dynamic value) {
    if (value == true || '$value'.toLowerCase() == 'true' || '$value' == '1') {
      return 'Có';
    }
    return 'Không';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: dataSource.getUserDetail(token, userId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 280,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    snapshot.error?.toString() ??
                        'Không thể tải chi tiết người dùng',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              );
            }

            final data = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Chi tiết người dùng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DetailRow(label: 'ID', value: _field(data, const ['id'])),
                  _DetailRow(
                    label: 'Họ tên',
                    value: _field(data, const ['fullName', 'username']),
                  ),
                  _DetailRow(
                    label: 'Username',
                    value: _field(data, const ['username']),
                  ),
                  _DetailRow(
                    label: 'Email',
                    value: _field(data, const ['email']),
                  ),
                  _DetailRow(
                    label: 'SĐT',
                    value: _field(data, const ['phoneNumber', 'phone']),
                  ),
                  _DetailRow(
                    label: 'Vai trò',
                    value: _field(data, const [
                      'role',
                    ], fallback: 'CUSTOMER').toUpperCase(),
                  ),
                  _DetailRow(
                    label: 'Hoạt động',
                    value: _boolText(data['isActive'] ?? data['active']),
                  ),
                  _DetailRow(
                    label: 'Email đã xác thực',
                    value: _boolText(data['isEmailVerified']),
                  ),
                  _DetailRow(
                    label: 'Ngày sinh',
                    value: _field(data, const ['birthDate']),
                  ),
                  _DetailRow(
                    label: 'Ngày tạo',
                    value: _field(data, const ['createdAt']),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserEditorSheet extends StatefulWidget {
  const _UserEditorSheet({
    required this.token,
    required this.dataSource,
    this.existing,
  });

  final String token;
  final AdminRemoteDataSource dataSource;
  final Map<String, dynamic>? existing;

  @override
  State<_UserEditorSheet> createState() => _UserEditorSheetState();
}

class _UserEditorSheetState extends State<_UserEditorSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;

  late String _role;
  late bool _isActive;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;
    _usernameController = TextEditingController(
      text: '${existing?['username'] ?? ''}',
    );
    _fullNameController = TextEditingController(
      text: '${existing?['fullName'] ?? existing?['name'] ?? ''}',
    );
    _emailController = TextEditingController(
      text: '${existing?['email'] ?? ''}',
    );
    _phoneController = TextEditingController(
      text: '${existing?['phoneNumber'] ?? existing?['phone'] ?? ''}',
    );
    _passwordController = TextEditingController();

    final roleRaw = '${existing?['role'] ?? 'CUSTOMER'}'.trim().toUpperCase();
    _role = roleRaw == 'ADMIN' ? 'ADMIN' : 'CUSTOMER';
    _isActive = existing == null ? true : (existing['isActive'] == true);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    final payload = <String, dynamic>{
      'username': _usernameController.text.trim(),
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneNumber': _phoneController.text.trim(),
      'role': _role,
      'isActive': _isActive,
    };

    if (_passwordController.text.trim().isNotEmpty) {
      payload['password'] = _passwordController.text.trim();
    }

    payload.removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        // Chỉ remove phoneNumber nếu empty, khác với password
        if (key == 'phoneNumber' && value.trim().isEmpty) {
          return true;
        }
        // Không remove password nếu là tạo mới (password bắt buộc)
        if (key == 'password' && _isEditing) {
          return value.trim().isEmpty;
        }
        return false;
      }
      return false;
    });

    try {
      if (_isEditing) {
        final id = '${widget.existing?['id'] ?? ''}'.trim();
        if (id.isEmpty) {
          throw Exception('Không có id user để cập nhật');
        }
        await widget.dataSource.updateUser(widget.token, id, payload);
      } else {
        await widget.dataSource.createUser(widget.token, payload);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lưu người dùng thất bại')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Sửa người dùng' : 'Thêm người dùng',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập username';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Họ và tên',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập họ tên';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty || !text.contains('@')) {
                      return 'Email không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: _isEditing
                        ? 'Mật khẩu mới (để trống nếu không đổi)'
                        : 'Mật khẩu',
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (!_isEditing) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Mật khẩu không được để trống';
                      }
                      if (value.trim().length < 6) {
                        return 'Mật khẩu tối thiểu 6 ký tự';
                      }
                    } else if (value != null && value.isNotEmpty) {
                      if (value.trim().length < 6) {
                        return 'Mật khẩu tối thiểu 6 ký tự';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _role,
                  decoration: const InputDecoration(
                    labelText: 'Vai trò',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem<String>(
                      value: 'CUSTOMER',
                      child: Text('CUSTOMER'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'ADMIN',
                      child: Text('ADMIN'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _role = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 6),
                SwitchListTile.adaptive(
                  value: _isActive,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Trạng thái hoạt động'),
                  onChanged: (value) {
                    setState(() {
                      _isActive = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting
                          ? 'Đang lưu...'
                          : (_isEditing ? 'Lưu thay đổi' : 'Tạo người dùng'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

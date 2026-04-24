import 'package:flutter/material.dart';

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
  late Future<AdminPageResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AdminPageResult> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }
    return widget.dataSource.getUsers(token, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _future = _load();
        });
        await _future;
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          AdminTopBar(
            title: 'QUẢN LÝ NGƯỜI DÙNG',
            role: widget.authController.userRole ?? 'ADMIN',
            onLogout: () => widget.authController.logout(),
          ),
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

              final users = snapshot.data!.items;
              if (users.isEmpty) {
                return const _Card(
                  child: Text('Không tìm thấy người dùng nào'),
                );
              }

              return Column(
                children: users.map((user) {
                  final username =
                      '${user['username'] ?? user['fullName'] ?? user['email'] ?? 'N/A'}';
                  final role = '${user['role'] ?? 'USER'}';
                  final active = user['active'];
                  final activeText = active == true
                      ? 'ĐANG HOẠT ĐỘNG'
                      : 'NGỪNG HOẠT ĐỘNG';

                  return _Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(username),
                      subtitle: Text('Vai trò: $role | $activeText'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
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

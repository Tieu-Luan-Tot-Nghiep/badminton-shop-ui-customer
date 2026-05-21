import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import 'admin_chat_inbox_page.dart';
import 'admin_promotions_page.dart';
import '../widgets/admin_top_bar.dart';

class AdminSystemPage extends StatefulWidget {
  const AdminSystemPage({
    super.key,
    required this.authController,
    required this.dataSource,
    this.onNavigateToAdminTab,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;
  final ValueChanged<int>? onNavigateToAdminTab;

  @override
  State<AdminSystemPage> createState() => _AdminSystemPageState();
}

class _AdminSystemPageState extends State<AdminSystemPage> {
  late Future<_SystemBundle> _future;
  bool _runningReindex = false;

  Future<void> _openChatInboxFromTopBar() async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminChatInboxPage(
          authController: widget.authController,
          dataSource: widget.dataSource,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SystemBundle> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final results = await Future.wait<dynamic>([
      widget.dataSource.getPromotions(token, size: 5),
      widget.dataSource.getLowStock(token, threshold: 8),
      widget.dataSource.getAdminChatInbox(token, size: 5),
    ]);

    return _SystemBundle(
      promotions: results[0] as AdminPageResult,
      lowStock: results[1] as List<Map<String, dynamic>>,
      chatInbox: results[2] as AdminPageResult,
    );
  }

  Future<void> _reindex() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _runningReindex = true;
    });

    try {
      await widget.dataSource.reindexSearch(token);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi yêu cầu lập chỉ mục lại')),
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lập chỉ mục lại thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _runningReindex = false;
        });
      }
    }
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
            title: 'VẬN HÀNH HỆ THỐNG',
            role: widget.authController.userRole ?? 'ADMIN',
            actions: [
              IconButton(
                onPressed: _openChatInboxFromTopBar,
                icon: const Icon(
                  Icons.chat_bubble_rounded,
                  color: AppColors.textPrimary,
                ),
                tooltip: 'Hộp thư chat quản trị',
              ),
            ],
            onLogout: () => widget.authController.logout(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_SystemBundle>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _Block(
                  child: Text(
                    snapshot.error?.toString() ??
                        'Không thể tải dữ liệu hệ thống',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final data = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle(
                    icon: Icons.apps_rounded,
                    title: 'Điều hướng nhanh',
                    subtitle: 'Mở nhanh các khu vực quản trị chính',
                  ),
                  const SizedBox(height: 8),
                  _Block(
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ActionPill(
                                icon: Icons.warehouse_rounded,
                                label: 'Kho',
                                onTap: () {
                                  widget.onNavigateToAdminTab?.call(2);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Đã chuyển sang trang Sản phẩm/Kho',
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _ActionPill(
                                icon: Icons.local_offer_rounded,
                                label: 'Khuyến mãi',
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminPromotionsPage(
                                        authController: widget.authController,
                                        dataSource: widget.dataSource,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SectionTitle(
                    icon: Icons.travel_explore_rounded,
                    title: 'Tìm kiếm sản phẩm',
                    subtitle:
                        'Đồng bộ lại chỉ mục để kết quả tìm kiếm chính xác hơn',
                  ),
                  const SizedBox(height: 8),
                  _Block(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lập chỉ mục tìm kiếm',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nên chạy sau khi cập nhật dữ liệu sản phẩm, giá, tồn kho hoặc khuyến mãi.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _runningReindex
                                    ? 'Đang gửi yêu cầu đến server...'
                                    : 'Sẵn sàng chạy lập chỉ mục',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: _runningReindex ? null : _reindex,
                              icon: _runningReindex
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.sync_rounded),
                              label: Text(
                                _runningReindex ? 'Đang chạy' : 'Chạy ngay',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ListSummary(
                    icon: Icons.inventory_2_rounded,
                    title: 'Biến Thể Sắp Hết Hàng',
                    rows: data.lowStock,
                    formatter: (item) {
                      final sku =
                          '${item['sku'] ?? item['productVariantId'] ?? 'N/A'}';
                      final qty = '${item['quantity'] ?? item['stock'] ?? 0}';
                      return '$sku (SL: $qty)';
                    },
                  ),
                  const SizedBox(height: 10),
                  _ListSummary(
                    icon: Icons.discount_rounded,
                    title: 'Khuyến Mãi Đang Hoạt Động',
                    rows: data.promotions.items,
                    formatter: (item) =>
                        '${item['code'] ?? item['name'] ?? item['id'] ?? 'N/A'}',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SystemBundle {
  const _SystemBundle({
    required this.promotions,
    required this.lowStock,
    required this.chatInbox,
  });

  final AdminPageResult promotions;
  final List<Map<String, dynamic>> lowStock;
  final AdminPageResult chatInbox;
}

class _Block extends StatelessWidget {
  const _Block({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

class _ListSummary extends StatelessWidget {
  const _ListSummary({
    required this.icon,
    required this.title,
    required this.rows,
    required this.formatter,
  });

  final IconData icon;
  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) formatter;

  @override
  Widget build(BuildContext context) {
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primaryContainer),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('Không có dữ liệu')
          else
            ...rows.take(5).map((row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('- ${formatter(row)}'),
              );
            }),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AdminChatInboxSheet extends StatelessWidget {
  const _AdminChatInboxSheet({required this.rows});

  final List<Map<String, dynamic>> rows;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.chat_bubble_rounded),
                const SizedBox(width: 8),
                Text(
                  'Hộp thư chat quản trị',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (rows.isEmpty)
              const Text('Hiện chưa có phòng chat nào.')
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final roomId =
                        '${row['roomId'] ?? row['conversationId'] ?? row['id'] ?? 'Room'}';
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.forum_outlined),
                      title: Text(
                        roomId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

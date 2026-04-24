import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';

class AdminSystemPage extends StatefulWidget {
  const AdminSystemPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminSystemPage> createState() => _AdminSystemPageState();
}

class _AdminSystemPageState extends State<AdminSystemPage> {
  late Future<_SystemBundle> _future;
  bool _runningReindex = false;

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
                  _Block(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Lập chỉ mục lại tìm kiếm sản phẩm'),
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
                          label: const Text('Chạy'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _ListSummary(
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
                    title: 'Khuyến Mãi Đang Hoạt Động',
                    rows: data.promotions.items,
                    formatter: (item) =>
                        '${item['code'] ?? item['name'] ?? item['id'] ?? 'N/A'}',
                  ),
                  const SizedBox(height: 10),
                  _ListSummary(
                    title: 'Hộp Thư Chat Quản Trị',
                    rows: data.chatInbox.items,
                    formatter: (item) =>
                        '${item['roomId'] ?? item['conversationId'] ?? 'Room'}',
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
    required this.title,
    required this.rows,
    required this.formatter,
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final String Function(Map<String, dynamic>) formatter;

  @override
  Widget build(BuildContext context) {
    return _Block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
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

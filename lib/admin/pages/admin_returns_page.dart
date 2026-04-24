import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';

class AdminReturnsPage extends StatefulWidget {
  const AdminReturnsPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminReturnsPage> createState() => _AdminReturnsPageState();
}

class _AdminReturnsPageState extends State<AdminReturnsPage> {
  late Future<_ReturnsBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ReturnsBundle> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final results = await Future.wait<dynamic>([
      widget.dataSource.getReturns(token),
      widget.dataSource.getReturnStats(token),
    ]);

    return _ReturnsBundle(
      returns: results[0] as AdminPageResult,
      stats: results[1] as Map<String, dynamic>,
    );
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
            title: 'YÊU CẦU ĐỔI TRẢ',
            role: widget.authController.userRole ?? 'ADMIN',
            onLogout: () => widget.authController.logout(),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_ReturnsBundle>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _StateBlock(
                  child: Text(
                    snapshot.error?.toString() ??
                        'Không thể tải dữ liệu đổi trả',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                );
              }

              final bundle = snapshot.data!;
              final entries = bundle.stats.entries.toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StateBlock(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: entries.isEmpty
                          ? const [Text('Chưa có thống kê đổi trả')]
                          : entries.map((entry) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${entry.key}: ${entry.value}'),
                              );
                            }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...bundle.returns.items.map((item) {
                    final id = '${item['id'] ?? item['requestId'] ?? 'N/A'}';
                    final status = '${item['status'] ?? 'UNKNOWN'}';
                    final note =
                        '${item['reason'] ?? item['description'] ?? ''}';

                    return _StateBlock(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Phiếu đổi trả #$id'),
                        subtitle: Text(
                          'Trạng thái: $status\n$note',
                          maxLines: 2,
                        ),
                      ),
                    );
                  }),
                  if (bundle.returns.items.isEmpty)
                    const _StateBlock(
                      child: Text('Không có yêu cầu đổi trả nào'),
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

class _ReturnsBundle {
  const _ReturnsBundle({required this.returns, required this.stats});

  final AdminPageResult returns;
  final Map<String, dynamic> stats;
}

class _StateBlock extends StatelessWidget {
  const _StateBlock({this.margin, required this.child});

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

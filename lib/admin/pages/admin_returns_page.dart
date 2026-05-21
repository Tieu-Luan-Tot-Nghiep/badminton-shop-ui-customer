import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

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
  final TextEditingController _keywordController = TextEditingController();
  String _selectedStatus = '';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<_ReturnsBundle> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final results = await Future.wait<dynamic>([
      widget.dataSource.getReturns(
        token,
        keyword: _keywordController.text.trim().isEmpty
            ? null
            : _keywordController.text.trim(),
        status: _selectedStatus.isEmpty ? null : _selectedStatus,
      ),
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
          _buildFilters(),
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
                  ...bundle.returns.items.map(_buildReturnCard),
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

  Widget _buildFilters() {
    return _StateBlock(
      child: Column(
        children: [
          TextField(
            controller: _keywordController,
            decoration: const InputDecoration(
              labelText: 'Tìm theo mã đơn / lý do',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onSubmitted: (_) => _reload(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStatus.isEmpty
                      ? null
                      : _selectedStatus,
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Tất cả')),
                    DropdownMenuItem(
                      value: 'REQUESTED',
                      child: Text('REQUESTED'),
                    ),
                    DropdownMenuItem(
                      value: 'AWAITING_RETURN',
                      child: Text('AWAITING_RETURN'),
                    ),
                    DropdownMenuItem(
                      value: 'REJECTED',
                      child: Text('REJECTED'),
                    ),
                    DropdownMenuItem(
                      value: 'RECEIVED',
                      child: Text('RECEIVED'),
                    ),
                    DropdownMenuItem(
                      value: 'REFUNDED',
                      child: Text('REFUNDED'),
                    ),
                  ],
                  onChanged: (value) {
                    _selectedStatus = value ?? '';
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _reload, child: const Text('Lọc')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReturnCard(Map<String, dynamic> item) {
    final id = '${item['id'] ?? item['requestId'] ?? 'N/A'}';
    final orderCode = '${item['orderCode'] ?? ''}';
    final status = '${item['status'] ?? 'UNKNOWN'}'.toUpperCase();
    final reason = '${item['reason'] ?? item['description'] ?? ''}'.trim();
    final refundMethod = '${item['refundMethod'] ?? ''}'.trim();

    return _StateBlock(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Phiếu #$id • Đơn $orderCode',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _statusChip(status),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Lý do: $reason'),
          ],
          if (refundMethod.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Hoàn tiền: $refundMethod'),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _buildActionButtons(item, status),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(Map<String, dynamic> item, String status) {
    final id = '${item['id'] ?? item['requestId'] ?? ''}'.trim();
    if (id.isEmpty) {
      return const <Widget>[];
    }

    if (_submitting) {
      return const [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ];
    }

    switch (status) {
      case 'REQUESTED':
        return [
          FilledButton.icon(
            onPressed: () => _approve(id),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Duyệt'),
          ),
          OutlinedButton.icon(
            onPressed: () => _reject(id),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Từ chối'),
          ),
        ];
      case 'AWAITING_RETURN':
        return [
          FilledButton.icon(
            onPressed: () => _receive(id, item),
            icon: const Icon(Icons.inventory_2_rounded),
            label: const Text('Nhận hàng trả'),
          ),
        ];
      case 'RECEIVED':
        return [
          FilledButton.icon(
            onPressed: () => _refund(id),
            icon: const Icon(Icons.payments_rounded),
            label: const Text('Đánh dấu hoàn tiền'),
          ),
        ];
      default:
        return const [
          Text(
            'Không có thao tác',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ];
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case 'REQUESTED':
        color = Colors.orangeAccent;
        break;
      case 'AWAITING_RETURN':
        color = Colors.blueAccent;
        break;
      case 'REJECTED':
        color = Colors.redAccent;
        break;
      case 'RECEIVED':
        color = Colors.cyanAccent;
        break;
      case 'REFUNDED':
        color = Colors.greenAccent;
        break;
      default:
        color = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _approve(String id) async {
    final note = await _askNote(title: 'Ghi chú duyệt (tuỳ chọn)');
    if (!mounted) return;
    await _runAction(() async {
      final token = widget.authController.session?.token ?? '';
      await widget.dataSource.approveReturn(token, id, note: note);
    }, success: 'Đã duyệt yêu cầu trả hàng.');
  }

  Future<void> _reject(String id) async {
    final note = await _askNote(title: 'Lý do từ chối', required: true);
    if (!mounted || note == null) return;
    await _runAction(() async {
      final token = widget.authController.session?.token ?? '';
      await widget.dataSource.rejectReturn(token, id, note: note);
    }, success: 'Đã từ chối yêu cầu trả hàng.');
  }

  Future<void> _receive(String id, Map<String, dynamic> raw) async {
    final payload = await _buildReceivePayload(raw);
    if (!mounted || payload == null) return;

    await _runAction(() async {
      final token = widget.authController.session?.token ?? '';
      await widget.dataSource.receiveReturn(token, id, payload);
    }, success: 'Đã cập nhật trạng thái đã nhận hàng trả.');
  }

  Future<void> _refund(String id) async {
    final note = await _askNote(title: 'Ghi chú hoàn tiền (tuỳ chọn)');
    if (!mounted) return;
    await _runAction(() async {
      final token = widget.authController.session?.token ?? '';
      await widget.dataSource.refundReturn(token, id, note: note);
    }, success: 'Đã đánh dấu hoàn tiền.');
  }

  Future<void> _runAction(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      final message = _readApiErrorMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  String _readApiErrorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      final status = error.response?.statusCode;
      if (status != null) {
        return 'Yêu cầu thất bại (HTTP $status).';
      }
    }
    return 'Có lỗi xảy ra, vui lòng thử lại.';
  }

  Future<String?> _askNote({
    required String title,
    bool required = false,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Nhập ghi chú'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (required && text.isEmpty) {
                  return;
                }
                Navigator.of(context).pop(text.isEmpty ? null : text);
              },
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<Map<String, dynamic>?> _buildReceivePayload(
    Map<String, dynamic> raw,
  ) async {
    final noteController = TextEditingController(text: 'Đã nhận hàng trả');
    final drafts = _extractReceiveItems(raw);

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Xác nhận nhận hàng trả'),
              content: SizedBox(
                width: 560,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: 'Ghi chú'),
                      ),
                      const SizedBox(height: 12),
                      ...drafts.map((draft) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  draft.productName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<int>(
                                value: draft.quantity,
                                items:
                                    List<int>.generate(
                                          draft.maxQty,
                                          (index) => index + 1,
                                        )
                                        .map(
                                          (value) => DropdownMenuItem<int>(
                                            value: value,
                                            child: Text('$value'),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setLocalState(() => draft.quantity = value);
                                },
                              ),
                              const SizedBox(width: 8),
                              DropdownButton<String>(
                                value: draft.action,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'RESTOCK',
                                    child: Text('RESTOCK'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'SCRAP',
                                    child: Text('SCRAP'),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setLocalState(() => draft.action = value);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
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
            );
          },
        );
      },
    );

    final note = noteController.text.trim();
    noteController.dispose();

    if (accepted != true) {
      return null;
    }

    return {
      'note': note,
      'items': drafts
          .map(
            (draft) => {
              'orderItemId': draft.orderItemId,
              'quantity': draft.quantity,
              'action': draft.action,
            },
          )
          .toList(),
    };
  }

  List<_ReceiveItemDraft> _extractReceiveItems(Map<String, dynamic> raw) {
    final dynamic source = raw['items'] ?? raw['returnItems'] ?? const [];
    final rows = source is List
        ? source.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];

    if (rows.isEmpty) {
      return [_ReceiveItemDraft(orderItemId: 0, productName: 'N/A', maxQty: 1)];
    }

    return rows.map((row) {
      final id = (row['orderItemId'] ?? row['id'] ?? 0);
      final parsedId = id is num ? id.toInt() : int.tryParse('$id') ?? 0;
      final requested =
          (row['requestedQuantity'] ?? row['quantity'] ?? 1) as dynamic;
      final maxQty = requested is num
          ? requested.toInt().clamp(1, 999)
          : (int.tryParse('$requested') ?? 1).clamp(1, 999);

      return _ReceiveItemDraft(
        orderItemId: parsedId,
        productName: '${row['productName'] ?? row['sku'] ?? 'Item'}',
        maxQty: maxQty,
      );
    }).toList();
  }
}

class _ReturnsBundle {
  const _ReturnsBundle({required this.returns, required this.stats});

  final AdminPageResult returns;
  final Map<String, dynamic> stats;
}

class _ReceiveItemDraft {
  _ReceiveItemDraft({
    required this.orderItemId,
    required this.productName,
    required this.maxQty,
  });

  final int orderItemId;
  final String productName;
  final int maxQty;
  int quantity = 1;
  String action = 'RESTOCK';
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

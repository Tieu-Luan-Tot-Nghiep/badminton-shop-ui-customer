import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../datasources/admin_orders_local_data_source.dart';
import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import 'admin_order_detail_page.dart';
import '../widgets/admin_top_bar.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  static const List<String> _statusFilters = <String>[
    'ALL',
    'PENDING',
    'CONFIRMED',
    'SHIPPING',
    'DELIVERED',
    'CANCELLED',
  ];
  static const List<String> _paymentStatusFilters = <String>[
    'ALL',
    'AWAITING_PAYMENT',
    'PAID',
    'FAILED',
    'REFUNDED',
  ];
  static const List<String> _paymentMethodFilters = <String>[
    'ALL',
    'COD',
    'VNPAY',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'ALL';
  String _selectedPaymentStatus = 'ALL';
  String _selectedPaymentMethod = 'ALL';
  final AdminOrdersLocalDataSource _localOrders = AdminOrdersLocalDataSource();
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
    final status = _selectedStatus == 'ALL' ? null : _selectedStatus;
    final paymentStatus = _selectedPaymentStatus == 'ALL'
        ? null
        : _selectedPaymentStatus;
    final paymentMethod = _selectedPaymentMethod == 'ALL'
        ? null
        : _selectedPaymentMethod;

    final cacheKey = _ordersCacheKey(
      keyword: keyword,
      status: status,
      paymentStatus: paymentStatus,
      paymentMethod: paymentMethod,
      page: 0,
      size: 20,
    );

    try {
      final result = await widget.dataSource.getOrders(
        token,
        keyword: keyword,
        status: status,
        paymentStatus: paymentStatus,
        paymentMethod: paymentMethod,
      );
      await _localOrders.cacheOrders(cacheKey, result);
      return result;
    } catch (_) {
      final cached = await _localOrders.getCachedOrders(cacheKey);
      if (cached == null) {
        rethrow;
      }
      return cached;
    }
  }

  String _ordersCacheKey({
    required String? keyword,
    required String? status,
    required String? paymentStatus,
    required String? paymentMethod,
    required int page,
    required int size,
  }) {
    return [
      'page=$page',
      'size=$size',
      'keyword=${keyword ?? ''}',
      'status=${status ?? ''}',
      'paymentStatus=${paymentStatus ?? ''}',
      'paymentMethod=${paymentMethod ?? ''}',
    ].join('|');
  }

  Future<void> _confirmOrder(String orderCode) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.updateOrderStatus(
        token,
        orderCode,
        status: 'CONFIRMED',
        note: 'Xác nhận từ danh sách đơn hàng',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xác nhận đơn hàng.')));
      setState(() {
        _future = _load();
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể xác nhận đơn: $error')));
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
            title: 'QUẢN LÝ ĐƠN HÀNG',
            role: widget.authController.userRole ?? 'ADMIN',
            onLogout: () => widget.authController.logout(),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer.withValues(alpha: 0.75),
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
                    decoration: const InputDecoration(
                      hintText: 'Tìm theo mã đơn hoặc khách hàng',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) {
                      setState(() {
                        _future = _load();
                      });
                    },
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _future = _load();
                    });
                  },
                  child: const Text('Tìm kiếm'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _statusFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final value = _statusFilters[index];
                final selected = value == _selectedStatus;

                return ChoiceChip(
                  selected: selected,
                  label: Text(_statusLabel(value)),
                  onSelected: (_) {
                    setState(() {
                      _selectedStatus = value;
                      _future = _load();
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final vertical = constraints.maxWidth < 520;

              final paymentStatusField = DropdownButtonFormField<String>(
                initialValue: _selectedPaymentStatus,
                isExpanded: true,
                items: _paymentStatusFilters
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          _paymentStatusLabel(value),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Trạng thái thanh toán',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedPaymentStatus = value;
                    _future = _load();
                  });
                },
              );

              final paymentMethodField = DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMethod,
                isExpanded: true,
                items: _paymentMethodFilters
                    .map(
                      (value) => DropdownMenuItem<String>(
                        value: value,
                        child: Text(
                          _paymentMethodLabel(value),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                decoration: const InputDecoration(
                  labelText: 'Phương thức thanh toán',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _selectedPaymentMethod = value;
                    _future = _load();
                  });
                },
              );

              if (vertical) {
                return Column(
                  children: [
                    paymentStatusField,
                    const SizedBox(height: 10),
                    paymentMethodField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: paymentStatusField),
                  const SizedBox(width: 10),
                  Expanded(child: paymentMethodField),
                ],
              );
            },
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
                return _ErrorTile(
                  message:
                      snapshot.error?.toString() ??
                      'Không thể tải danh sách đơn hàng',
                  onRetry: () {
                    setState(() {
                      _future = _load();
                    });
                  },
                );
              }

              final result = snapshot.data!;
              if (result.items.isEmpty) {
                return const _EmptyTile(message: 'Không tìm thấy đơn hàng nào');
              }

              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tổng: ${result.totalElements}',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...result.items.map((order) {
                    final orderCode =
                        '${order['orderCode'] ?? order['id'] ?? 'N/A'}';
                    final customer =
                        '${order['fullName'] ?? order['customerName'] ?? order['receiverName'] ?? order['username'] ?? 'Không rõ'}';
                    final statusRaw = '${order['status'] ?? 'UNKNOWN'}';
                    final paymentStatusRaw = '${order['paymentStatus'] ?? ''}';
                    final paymentMethodRaw = '${order['paymentMethod'] ?? ''}';
                    final amount = _extractOrderAmount(order);
                    final amountText = NumberFormat.decimalPattern(
                      'vi_VN',
                    ).format(amount);
                    final createdText = _orderCreatedText(order);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.75,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          final changed = await Navigator.of(context)
                              .push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => AdminOrderDetailPage(
                                    orderCode: orderCode,
                                    authController: widget.authController,
                                    dataSource: widget.dataSource,
                                  ),
                                ),
                              );

                          if (changed == true && mounted) {
                            setState(() {
                              _future = _load();
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          customer,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          orderCode,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                fontFamily: 'monospace',
                                                color: AppColors.textSecondary,
                                                fontSize: 12,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Đặt lúc: $createdText',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    '$amountText VND',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: AppColors.primaryContainer,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildStatusBadge(
                                    _statusLabel(statusRaw),
                                    _orderStatusColor(statusRaw),
                                  ),
                                  _buildStatusBadge(
                                    _paymentBadgeLabel(
                                      paymentStatusRaw,
                                      paymentMethodRaw,
                                    ),
                                    _paymentStatusColor(paymentStatusRaw),
                                  ),
                                ],
                              ),
                              if (statusRaw.toUpperCase() == 'PENDING') ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: FilledButton(
                                    onPressed: () => _confirmOrder(orderCode),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          AppColors.primaryContainer,
                                      foregroundColor:
                                          AppColors.onPrimaryContainer,
                                    ),
                                    child: const Text('Xác nhận'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _orderCreatedText(Map<String, dynamic> order) {
    final raw =
        '${order['createdAt'] ?? order['orderDate'] ?? order['createdDate'] ?? ''}'
            .trim();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return '--';
    }
    return DateFormat('HH:mm dd/MM/yyyy').format(parsed.toLocal());
  }

  double _extractOrderAmount(Map<String, dynamic> order) {
    return _toDouble(
      order['grandTotal'] ??
          order['totalAmount'] ??
          order['total'] ??
          order['finalAmount'] ??
          order['itemsAmount'] ??
          0,
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  String _paymentBadgeLabel(String paymentStatus, String paymentMethod) {
    final normalizedStatus = paymentStatus.trim();
    if (normalizedStatus.isNotEmpty && normalizedStatus != 'N/A') {
      return _paymentStatusLabel(normalizedStatus);
    }

    final normalizedMethod = paymentMethod.trim();
    if (normalizedMethod.isNotEmpty && normalizedMethod != 'N/A') {
      return 'PTTT: ${_paymentMethodLabel(normalizedMethod)}';
    }
    return 'Thanh toán: Chưa rõ';
  }

  Color _orderStatusColor(String value) {
    switch (value.toUpperCase()) {
      case 'DELIVERED':
        return Colors.green;
      case 'CANCELLED':
        return Colors.redAccent;
      case 'SHIPPING':
        return Colors.blueAccent;
      case 'CONFIRMED':
        return Colors.cyan;
      default:
        return Colors.orangeAccent;
    }
  }

  Color _paymentStatusColor(String value) {
    switch (value.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
        return Colors.green;
      case 'FAILED':
        return Colors.redAccent;
      case 'REFUNDED':
        return Colors.amber;
      case 'AWAITING_PAYMENT':
      case 'PENDING':
        return Colors.orangeAccent;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget _buildStatusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _statusLabel(String value) {
  switch (value.toUpperCase()) {
    case 'ALL':
      return 'Tất cả';
    case 'PENDING':
      return 'Chờ xác nhận';
    case 'CONFIRMED':
      return 'Đã xác nhận';
    case 'SHIPPING':
      return 'Đang giao';
    case 'DELIVERED':
      return 'Đã giao';
    case 'CANCELLED':
      return 'Đã hủy';
    default:
      return value;
  }
}

String _paymentStatusLabel(String value) {
  switch (value.toUpperCase()) {
    case 'ALL':
      return 'Tất cả';
    case 'AWAITING_PAYMENT':
      return 'Chờ thanh toán';
    case 'COMPLETED':
      return 'Đã hoàn tất';
    case 'PENDING':
      return 'Đang xử lý';
    case 'PAID':
      return 'Đã thanh toán';
    case 'FAILED':
      return 'Thanh toán lỗi';
    case 'REFUNDED':
      return 'Đã hoàn tiền';
    default:
      return value;
  }
}

String _paymentMethodLabel(String value) {
  switch (value.toUpperCase()) {
    case 'ALL':
      return 'Tất cả';
    case 'COD':
      return 'COD';
    case 'VNPAY':
      return 'VNPay';
    default:
      return value;
  }
}

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        message,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

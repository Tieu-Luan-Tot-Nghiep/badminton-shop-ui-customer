import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import 'admin_order_detail_page.dart';
import '../widgets/admin_top_bar.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  _RevenueViewMode _revenueMode = _RevenueViewMode.month;
  _MoneyDisplayMode _moneyDisplayMode = _MoneyDisplayMode.short;
  late DateTime _selectedWeekStart;
  DateTime _selectedMonth = DateTime.now();
  int _selectedYear = DateTime.now().year;
  late Future<_DashboardBundle> _future;
  _DashboardBundle? _cachedBundle;
  bool _isRevenueLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = _startOfWeek(DateTime.now());
    _future = _load();
  }

  Future<_DashboardBundle> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      throw Exception('Thiếu access token');
    }

    final now = DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd');
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final revenueQuery = _buildRevenueQuery(now);

    final results = await Future.wait<dynamic>([
      widget.dataSource.getDashboardKpis(token),
      _fetchRevenueSeries(token, revenueQuery: revenueQuery, dateFmt: dateFmt),
      widget.dataSource.getOrders(token, page: 0, size: 1),
      widget.dataSource.getProductsAdmin(token, page: 0, size: 1),
      widget.dataSource.getUsers(token, page: 0, size: 1),
      widget.dataSource.getReturns(token, page: 0, size: 1),
      widget.dataSource.getOrders(
        token,
        page: 0,
        size: 20,
        from: todayStart.toIso8601String(),
        to: todayEnd.toIso8601String(),
      ),
    ]);

    final kpis = Map<String, dynamic>.from(results[0] as Map<String, dynamic>);
    final revenueSeries = results[1] as List<Map<String, dynamic>>;
    final ordersPage = results[2] as AdminPageResult;
    final productsPage = results[3] as AdminPageResult;
    final usersPage = results[4] as AdminPageResult;
    final returnsPage = results[5] as AdminPageResult;
    final todayOrdersPage = results[6] as AdminPageResult;

    kpis['totalOrders'] = _preferNonZero(
      kpis['totalOrders'],
      ordersPage.totalElements,
    );
    kpis['totalProducts'] = _preferNonZero(
      kpis['totalProducts'],
      productsPage.totalElements,
    );
    kpis['totalUsers'] = _preferNonZero(
      kpis['totalUsers'],
      usersPage.totalElements,
    );
    kpis['totalReturns'] = _preferNonZero(
      kpis['totalReturns'],
      returnsPage.totalElements,
    );

    return _DashboardBundle(
      kpis: kpis,
      recentOrders: todayOrdersPage.items,
      revenueSeries: revenueSeries,
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRevenueSeries(
    String token, {
    _RevenueQuery? revenueQuery,
    DateFormat? dateFmt,
  }) {
    final query = revenueQuery ?? _buildRevenueQuery(DateTime.now());
    final fmt = dateFmt ?? DateFormat('yyyy-MM-dd');

    return widget.dataSource.getDashboardRevenue(
      token,
      startDate: fmt.format(query.startDate),
      endDate: fmt.format(query.endDate),
      groupBy: query.groupBy,
    );
  }

  Future<void> _loadRevenueOnly() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    if (_cachedBundle == null) {
      setState(() {
        _future = _load();
      });
      return;
    }

    setState(() {
      _isRevenueLoading = true;
    });

    try {
      final revenueSeries = await _fetchRevenueSeries(token);
      if (!mounted) {
        return;
      }
      setState(() {
        _cachedBundle = _cachedBundle!.copyWith(revenueSeries: revenueSeries);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể tải dữ liệu doanh thu.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRevenueLoading = false;
        });
      }
    }
  }

  int _asInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  String _dashboardStatusLabel(String value) {
    switch (value.toUpperCase()) {
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

  Color _dashboardStatusColor(String value) {
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

  int _preferNonZero(dynamic current, int fallback) {
    final currentValue = _asInt(current);
    return currentValue > 0 ? currentValue : fallback;
  }

  _RevenueQuery _buildRevenueQuery(DateTime now) {
    switch (_revenueMode) {
      case _RevenueViewMode.week:
        final thisWeek = _startOfWeek(now);
        if (_selectedWeekStart.isAfter(thisWeek)) {
          _selectedWeekStart = thisWeek;
        }
        return _RevenueQuery(
          startDate: _selectedWeekStart,
          endDate: _selectedWeekStart.add(const Duration(days: 6)),
          groupBy: 'DAY',
        );
      case _RevenueViewMode.month:
        final start = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
        final end = start.add(const Duration(days: 29));
        return _RevenueQuery(startDate: start, endDate: end, groupBy: 'DAY');
      case _RevenueViewMode.year:
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear, 12, 31);
        return _RevenueQuery(startDate: start, endDate: end, groupBy: 'MONTH');
    }
  }

  DateTime _startOfWeek(DateTime input) {
    final normalized = DateTime(input.year, input.month, input.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  void _changeRevenueMode(_RevenueViewMode mode) {
    if (_revenueMode == mode) {
      return;
    }
    setState(() {
      _revenueMode = mode;
    });
    _loadRevenueOnly();
  }

  void _changeMoneyDisplayMode(_MoneyDisplayMode mode) {
    if (_moneyDisplayMode == mode) {
      return;
    }
    setState(() {
      _moneyDisplayMode = mode;
    });
  }

  void _previousWeek() {
    setState(() {
      _selectedWeekStart = _selectedWeekStart.subtract(const Duration(days: 7));
    });
    _loadRevenueOnly();
  }

  void _nextWeek() {
    final thisWeek = _startOfWeek(DateTime.now());
    final next = _selectedWeekStart.add(const Duration(days: 7));
    if (next.isAfter(thisWeek)) {
      return;
    }
    setState(() {
      _selectedWeekStart = next;
    });
    _loadRevenueOnly();
  }

  Future<void> _pickRevenueMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      helpText: 'Chọn tháng',
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });
    _loadRevenueOnly();
  }

  Future<void> _pickRevenueYear() async {
    final current = DateTime.now().year;
    final years = List<int>.generate(8, (index) => current - index);

    final picked = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn năm'),
        content: SizedBox(
          width: 220,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: years.length,
            itemBuilder: (_, index) {
              final year = years[index];
              return ListTile(
                title: Text('Năm $year'),
                onTap: () => Navigator.of(context).pop(year),
              );
            },
          ),
        ),
      ),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedYear = picked;
    });
    _loadRevenueOnly();
  }

  Future<void> _confirmOrderFromDashboard(String orderCode) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.updateOrderStatus(
        token,
        orderCode,
        status: 'CONFIRMED',
        note: 'Xác nhận từ tổng quan',
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
            title: 'TỔNG QUAN QUẢN TRỊ',
            role: widget.authController.userRole ?? 'ADMIN',
            onLogout: () => widget.authController.logout(),
          ),
          const SizedBox(height: 14),
          FutureBuilder<_DashboardBundle>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                _cachedBundle = snapshot.data;
              }

              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedBundle == null) {
                return const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError || !snapshot.hasData) {
                return _ErrorCard(
                  message:
                      snapshot.error?.toString() ??
                      'Không thể tải dữ liệu tổng quan',
                  onRetry: () {
                    setState(() {
                      _future = _load();
                    });
                  },
                );
              }

              final data = snapshot.data ?? _cachedBundle!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _KpiGrid(kpis: data.kpis),
                  const SizedBox(height: 14),
                  _RevenueChartCard(
                    rows: data.revenueSeries,
                    isLoading: _isRevenueLoading,
                    mode: _revenueMode,
                    moneyDisplayMode: _moneyDisplayMode,
                    selectedWeekStart: _selectedWeekStart,
                    selectedMonth: _selectedMonth,
                    selectedYear: _selectedYear,
                    onModeChanged: _changeRevenueMode,
                    onMoneyDisplayModeChanged: _changeMoneyDisplayMode,
                    onPreviousWeek: _previousWeek,
                    onNextWeek: _nextWeek,
                    onPickMonth: _pickRevenueMonth,
                    onPickYear: _pickRevenueYear,
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: 'Đơn Hàng Trong Ngày',
                    child: data.recentOrders.isEmpty
                        ? const _EmptyState(
                            text: 'Hôm nay chưa có đơn hàng nào',
                          )
                        : Column(
                            children: data.recentOrders.take(5).map((order) {
                              final code =
                                  '${order['orderCode'] ?? order['id'] ?? 'N/A'}';
                              final status = '${order['status'] ?? 'UNKNOWN'}';
                              final customer =
                                  '${order['fullName'] ?? order['customerName'] ?? order['receiverName'] ?? order['username'] ?? 'Không rõ'}';
                              final total = _toDouble(
                                order['grandTotal'] ??
                                    order['totalAmount'] ??
                                    order['total'] ??
                                    order['itemsAmount'] ??
                                    0,
                              );
                              final createdRaw =
                                  '${order['createdAt'] ?? order['orderDate'] ?? order['createdDate'] ?? ''}'
                                      .trim();
                              final createdAt = DateTime.tryParse(createdRaw);
                              final createdText = createdAt == null
                                  ? '--'
                                  : DateFormat(
                                      'HH:mm dd/MM/yyyy',
                                    ).format(createdAt.toLocal());
                              final totalText = NumberFormat.decimalPattern(
                                'vi_VN',
                              ).format(total);
                              final statusLabel = _dashboardStatusLabel(status);
                              final statusColor = _dashboardStatusColor(status);
                              final isPending =
                                  status.toUpperCase() == 'PENDING';

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () async {
                                    final orderCode =
                                        '${order['orderCode'] ?? order['id'] ?? ''}'
                                            .trim();
                                    if (orderCode.isEmpty) {
                                      return;
                                    }

                                    final changed = await Navigator.of(context)
                                        .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                AdminOrderDetailPage(
                                                  orderCode: orderCode,
                                                  authController:
                                                      widget.authController,
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    customer,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    code,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                          fontFamily:
                                                              'monospace',
                                                        ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    createdText,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: AppColors
                                                              .textSecondary,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '$totalText VND',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: AppColors
                                                            .primaryContainer,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                ),
                                                const SizedBox(height: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 6,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withValues(
                                                          alpha: 0.16,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: statusColor
                                                          .withValues(
                                                            alpha: 0.52,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    statusLabel,
                                                    style: TextStyle(
                                                      color: statusColor,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (isPending) ...[
                                          const SizedBox(height: 10),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: FilledButton(
                                              onPressed: () =>
                                                  _confirmOrderFromDashboard(
                                                    code,
                                                  ),
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.primaryContainer,
                                                foregroundColor: AppColors
                                                    .onPrimaryContainer,
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
                            }).toList(),
                          ),
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

class _DashboardBundle {
  const _DashboardBundle({
    required this.kpis,
    required this.recentOrders,
    required this.revenueSeries,
  });

  final Map<String, dynamic> kpis;
  final List<Map<String, dynamic>> recentOrders;
  final List<Map<String, dynamic>> revenueSeries;

  _DashboardBundle copyWith({
    Map<String, dynamic>? kpis,
    List<Map<String, dynamic>>? recentOrders,
    List<Map<String, dynamic>>? revenueSeries,
  }) {
    return _DashboardBundle(
      kpis: kpis ?? this.kpis,
      recentOrders: recentOrders ?? this.recentOrders,
      revenueSeries: revenueSeries ?? this.revenueSeries,
    );
  }
}

enum _RevenueViewMode { week, month, year }

enum _MoneyDisplayMode { short, full }

class _RevenueQuery {
  const _RevenueQuery({
    required this.startDate,
    required this.endDate,
    required this.groupBy,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String groupBy;
}

class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({
    required this.rows,
    required this.isLoading,
    required this.mode,
    required this.moneyDisplayMode,
    required this.selectedWeekStart,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onModeChanged,
    required this.onMoneyDisplayModeChanged,
    required this.onPreviousWeek,
    required this.onNextWeek,
    required this.onPickMonth,
    required this.onPickYear,
  });

  final List<Map<String, dynamic>> rows;
  final bool isLoading;
  final _RevenueViewMode mode;
  final _MoneyDisplayMode moneyDisplayMode;
  final DateTime selectedWeekStart;
  final DateTime selectedMonth;
  final int selectedYear;
  final ValueChanged<_RevenueViewMode> onModeChanged;
  final ValueChanged<_MoneyDisplayMode> onMoneyDisplayModeChanged;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;
  final VoidCallback onPickMonth;
  final VoidCallback onPickYear;

  @override
  Widget build(BuildContext context) {
    final points = _buildSeries();
    final detailPoints = points.where((e) => e.revenue > 0).toList();
    final maxRevenue = points
        .map((e) => e.revenue)
        .fold<double>(0, (prev, current) => current > prev ? current : prev);
    final safeMax = maxRevenue <= 0 ? 1.0 : maxRevenue;
    final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'VND');
    final fullMoney = NumberFormat.decimalPattern('vi_VN');
    final dateFmt = DateFormat('MM/yyyy');
    final weekFmt = DateFormat('dd/MM');
    final yAxisWidth = moneyDisplayMode == _MoneyDisplayMode.full
        ? 104.0
        : 62.0;
    final chartWidth = math.max<double>(
      MediaQuery.of(context).size.width - 112,
      points.length * (mode == _RevenueViewMode.month ? 34.0 : 40.0),
    );
    final yTicks = <double>[safeMax, safeMax * 0.5, safeMax * 0.25, 0.0];

    return _SectionCard(
      title: 'Biểu đồ doanh thu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.surfaceContainerHighest.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                  child: ToggleButtons(
                    borderRadius: BorderRadius.circular(10),
                    isSelected: [
                      mode == _RevenueViewMode.week,
                      mode == _RevenueViewMode.month,
                      mode == _RevenueViewMode.year,
                    ],
                    onPressed: (index) {
                      if (index == 0) {
                        onModeChanged(_RevenueViewMode.week);
                      } else if (index == 1) {
                        onModeChanged(_RevenueViewMode.month);
                      } else {
                        onModeChanged(_RevenueViewMode.year);
                      }
                    },
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('7 ngày'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('30 ngày'),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('12 tháng'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (mode == _RevenueViewMode.week) ...[
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: onPreviousWeek,
                      child: const Icon(Icons.chevron_left_rounded),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      onPressed: onNextWeek,
                      child: const Icon(Icons.chevron_right_rounded),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${weekFmt.format(selectedWeekStart)} - ${weekFmt.format(selectedWeekStart.add(const Duration(days: 6)))}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (mode == _RevenueViewMode.month)
                  SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: onPickMonth,
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text('Tháng ${dateFmt.format(selectedMonth)}'),
                    ),
                  ),
                if (mode == _RevenueViewMode.year)
                  SizedBox(
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: onPickYear,
                      icon: const Icon(Icons.date_range_rounded, size: 16),
                      label: Text('Năm $selectedYear'),
                    ),
                  ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: PopupMenuButton<_MoneyDisplayMode>(
                    tooltip: 'Định dạng tiền',
                    initialValue: moneyDisplayMode,
                    onSelected: onMoneyDisplayModeChanged,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: _MoneyDisplayMode.short,
                        child: Text('Tiền rút gọn'),
                      ),
                      const PopupMenuItem(
                        value: _MoneyDisplayMode.full,
                        child: Text('Tiền đầy đủ'),
                      ),
                    ],
                    child: const Icon(Icons.tune_rounded),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Trục dọc: Doanh thu (VND)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const SizedBox(
              height: 180,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (points.every((e) => e.revenue <= 0))
            const _EmptyState(text: 'Không có dữ liệu doanh thu cho bộ lọc này')
          else
            SizedBox(
              height: 264,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: yAxisWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: yTicks
                          .map(
                            (tick) => FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _axisMoneyText(tick, fullMoney),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: AppColors.textSecondary.withValues(
                                        alpha: 0.78,
                                      ),
                                    ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      _DashedHorizontalLine(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.12),
                                      ),
                                      _DashedHorizontalLine(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.16),
                                      ),
                                      _DashedHorizontalLine(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.16),
                                      ),
                                      _DashedHorizontalLine(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.18),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: points.map((point) {
                                      final ratio = point.revenue / safeMax;
                                      final hasRevenue = point.revenue > 0;
                                      final barHeight = hasRevenue
                                          ? math.max<double>(6, ratio * 156)
                                          : 3.0;
                                      final barLabel = _barDataLabelText(
                                        point.revenue,
                                        fullMoney,
                                      );

                                      return Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 1,
                                          ),
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: FractionallySizedBox(
                                              widthFactor: 0.68,
                                              child: Tooltip(
                                                message:
                                                    '${point.label}: ${_moneyDisplayModeText(point.revenue, currency, fullMoney)} (${point.totalOrders} đơn)',
                                                child: Stack(
                                                  clipBehavior: Clip.none,
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  children: [
                                                    Container(
                                                      height: barHeight,
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            const BorderRadius.vertical(
                                                              top:
                                                                  Radius.circular(
                                                                    6,
                                                                  ),
                                                            ),
                                                        color: hasRevenue
                                                            ? AppColors
                                                                  .primaryContainer
                                                            : AppColors
                                                                  .surfaceContainerHighest
                                                                  .withValues(
                                                                    alpha: 0.45,
                                                                  ),
                                                        boxShadow: hasRevenue
                                                            ? [
                                                                BoxShadow(
                                                                  color: AppColors
                                                                      .primaryContainer
                                                                      .withValues(
                                                                        alpha:
                                                                            0.22,
                                                                      ),
                                                                  blurRadius: 6,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        1,
                                                                      ),
                                                                ),
                                                              ]
                                                            : null,
                                                      ),
                                                    ),
                                                    Positioned(
                                                      bottom: barHeight + 3,
                                                      child: Text(
                                                        barLabel,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              fontSize: 8,
                                                              color: hasRevenue
                                                                  ? AppColors
                                                                        .primaryContainer
                                                                  : AppColors
                                                                        .textSecondary
                                                                        .withValues(
                                                                          alpha:
                                                                              0.72,
                                                                        ),
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 34,
                              child: Row(
                                children: points.map((point) {
                                  return Expanded(
                                    child: Text(
                                      point.label,
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize:
                                                mode == _RevenueViewMode.month
                                                ? 8.5
                                                : 10,
                                          ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Chi tiết doanh thu',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 162,
            child: SingleChildScrollView(
              child: Column(
                children: (detailPoints.isEmpty ? points : detailPoints).map((
                  point,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          child: Text(
                            point.label,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _moneyDisplayModeText(
                              point.revenue,
                              currency,
                              fullMoney,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(
                            '${point.totalOrders} đơn',
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _shortMoney(double value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}T';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}Tr';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }

  String _moneyDisplayModeText(
    double value,
    NumberFormat currency,
    NumberFormat fullMoney,
  ) {
    if (moneyDisplayMode == _MoneyDisplayMode.full) {
      return '${fullMoney.format(value)} VND';
    }

    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    }
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(0)} triệu';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)} nghìn';
    }
    return currency.format(value);
  }

  String _axisMoneyText(double value, NumberFormat fullMoney) {
    if (moneyDisplayMode == _MoneyDisplayMode.full) {
      return fullMoney.format(value);
    }
    return _shortMoney(value);
  }

  String _barDataLabelText(double value, NumberFormat fullMoney) {
    if (value <= 0) {
      return '0';
    }
    if (moneyDisplayMode == _MoneyDisplayMode.full && value < 1000000) {
      return fullMoney.format(value);
    }
    return _shortMoney(value);
  }

  List<_RevenuePoint> _buildSeries() {
    switch (mode) {
      case _RevenueViewMode.week:
        return _buildWeekSeries();
      case _RevenueViewMode.month:
        return _buildMonthSeries();
      case _RevenueViewMode.year:
        return _buildYearSeries();
    }
  }

  List<_RevenuePoint> _buildWeekSeries() {
    final labels = const ['Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN'];
    final revenue = List<double>.filled(7, 0);
    final orders = List<int>.filled(7, 0);

    for (final row in rows) {
      final date = _extractPeriodDate(row);
      if (date == null) {
        continue;
      }
      final idx = date.weekday - 1;
      if (idx < 0 || idx >= 7) {
        continue;
      }
      revenue[idx] += _extractRevenue(row);
      orders[idx] += _extractOrders(row);
    }

    return List<_RevenuePoint>.generate(
      7,
      (i) => _RevenuePoint(
        label: labels[i],
        revenue: revenue[i],
        totalOrders: orders[i],
      ),
    );
  }

  List<_RevenuePoint> _buildMonthSeries() {
    const days = 30;
    final revenue = List<double>.filled(days, 0);
    final orders = List<int>.filled(days, 0);
    final start = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final end = start.add(const Duration(days: 29));

    for (final row in rows) {
      final date = _extractPeriodDate(row);
      if (date == null || date.isBefore(start) || date.isAfter(end)) {
        continue;
      }
      final idx = date.difference(start).inDays;
      if (idx < 0 || idx >= days) {
        continue;
      }

      revenue[idx] += _extractRevenue(row);
      orders[idx] += _extractOrders(row);
    }

    return List<_RevenuePoint>.generate(
      days,
      (i) => _RevenuePoint(
        label: DateFormat('dd/MM').format(start.add(Duration(days: i))),
        revenue: revenue[i],
        totalOrders: orders[i],
      ),
    );
  }

  List<_RevenuePoint> _buildYearSeries() {
    final revenue = List<double>.filled(12, 0);
    final orders = List<int>.filled(12, 0);

    for (final row in rows) {
      final monthIndex = _extractMonthIndex(row);
      if (monthIndex == null || monthIndex < 1 || monthIndex > 12) {
        continue;
      }

      final idx = monthIndex - 1;
      revenue[idx] += _extractRevenue(row);
      orders[idx] += _extractOrders(row);
    }

    return List<_RevenuePoint>.generate(
      12,
      (i) => _RevenuePoint(
        label: '${i + 1}',
        revenue: revenue[i],
        totalOrders: orders[i],
      ),
    );
  }

  dynamic _pickFirst(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row.containsKey(key)) {
        return row[key];
      }
    }
    return null;
  }

  String _pickFirstNonEmpty(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  DateTime? _extractPeriodDate(Map<String, dynamic> row) {
    final raw = _pickFirstNonEmpty(row, const [
      'period',
      'date',
      'day',
      'label',
      'time',
    ]);
    if (raw.isEmpty) {
      return null;
    }

    var parsed = DateTime.tryParse(raw);
    if (parsed != null) {
      return parsed;
    }

    if (RegExp(r'^\d{4}-\d{2}$').hasMatch(raw)) {
      parsed = DateTime.tryParse('$raw-01');
      if (parsed != null) {
        return parsed;
      }
    }

    return null;
  }

  int? _extractMonthIndex(Map<String, dynamic> row) {
    final monthRaw = _pickFirst(row, const ['month']);
    final monthFromField = _toInt(monthRaw);
    if (monthFromField >= 1 && monthFromField <= 12) {
      return monthFromField;
    }

    final date = _extractPeriodDate(row);
    return date?.month;
  }

  double _extractRevenue(Map<String, dynamic> row) {
    return _toDouble(
      _pickFirst(row, const ['totalRevenue', 'revenue', 'amount']),
    );
  }

  int _extractOrders(Map<String, dynamic> row) {
    return _toInt(
      _pickFirst(row, const ['totalOrders', 'orders', 'orderCount']),
    );
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  int _toInt(dynamic value) {
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse('$value') ?? 0;
  }
}

class _RevenuePoint {
  const _RevenuePoint({
    required this.label,
    required this.revenue,
    required this.totalOrders,
  });

  final String label;
  final double revenue;
  final int totalOrders;
}

class _DashedHorizontalLine extends StatelessWidget {
  const _DashedHorizontalLine({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 8).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount,
              (_) => SizedBox(
                width: 4,
                height: 1,
                child: DecoratedBox(decoration: BoxDecoration(color: color)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.kpis});

  final Map<String, dynamic> kpis;

  static const List<String> _preferredOrder = <String>[
    'totalProducts',
    'totalCustomers',
    'totalUsers',
    'totalOrders',
    'totalReturns',
    'pendingOrders',
  ];

  @override
  Widget build(BuildContext context) {
    final entries = _sortedEntries();
    if (entries.isEmpty) {
      return const _SectionCard(
        title: 'Chỉ số KPI',
        child: _EmptyState(text: 'Không có dữ liệu KPI'),
      );
    }

    return _SectionCard(
      title: 'Chỉ Số KPI',
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.take(6).length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.9,
        ),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final config = _kpiVisual(entry.key);
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerHighest.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: 2,
                  top: 2,
                  child: Icon(
                    config.icon,
                    size: 28,
                    color: config.color.withValues(alpha: 0.2),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Flexible(
                      child: Text(
                        _kpiLabel(entry.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          height: 1.0,
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.88,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${entry.value}',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryContainer,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  ({IconData icon, Color color}) _kpiVisual(String key) {
    switch (key) {
      case 'totalProducts':
        return (icon: Icons.inventory_2_rounded, color: Colors.cyanAccent);
      case 'totalCustomers':
        return (icon: Icons.person_rounded, color: Colors.lightBlueAccent);
      case 'totalUsers':
        return (icon: Icons.groups_rounded, color: Colors.tealAccent);
      case 'totalOrders':
        return (icon: Icons.receipt_long_rounded, color: Colors.orangeAccent);
      case 'totalReturns':
        return (
          icon: Icons.assignment_return_rounded,
          color: Colors.amberAccent,
        );
      case 'pendingOrders':
        return (icon: Icons.schedule_rounded, color: Colors.deepOrangeAccent);
      default:
        return (icon: Icons.insights_rounded, color: Colors.cyanAccent);
    }
  }

  List<MapEntry<String, dynamic>> _sortedEntries() {
    final map = Map<String, dynamic>.from(kpis);
    map.remove('totalRevenue');
    final ordered = <MapEntry<String, dynamic>>[];

    for (final key in _preferredOrder) {
      if (map.containsKey(key)) {
        ordered.add(MapEntry<String, dynamic>(key, map[key]));
        map.remove(key);
      }
    }

    final rest = map.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    ordered.addAll(rest);
    return ordered;
  }

  String _kpiLabel(String key) {
    switch (key) {
      case 'totalProducts':
        return 'Tổng sản phẩm';
      case 'totalCustomers':
        return 'Tổng khách hàng';
      case 'totalUsers':
        return 'Tổng người dùng';
      case 'totalOrders':
        return 'Tổng đơn hàng';
      case 'totalReturns':
        return 'Tổng yêu cầu đổi trả';
      case 'pendingOrders':
        return 'Đơn chờ xử lý';
      case 'cancelledOrders':
        return 'Đơn đã hủy';
      default:
        return key;
    }
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Lỗi',
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
    );
  }
}

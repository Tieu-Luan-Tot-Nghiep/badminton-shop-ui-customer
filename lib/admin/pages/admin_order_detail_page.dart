import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';

class AdminOrderDetailPage extends StatefulWidget {
  const AdminOrderDetailPage({
    super.key,
    required this.orderCode,
    required this.authController,
    required this.dataSource,
  });

  final String orderCode;
  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminOrderDetailPage> createState() => _AdminOrderDetailPageState();
}

class _AdminOrderDetailPageState extends State<AdminOrderDetailPage> {
  static const List<String> _statuses = <String>[
    'PENDING',
    'CONFIRMED',
    'SHIPPING',
    'DELIVERED',
    'CANCELLED',
  ];

  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _shippingCodeController = TextEditingController();
  final TextEditingController _shippingProviderController =
      TextEditingController();
  final TextEditingController _expectedDeliveryController =
      TextEditingController();

  bool _isSaving = false;
  Map<String, dynamic>? _detail;
  String? _selectedStatus;
  DateTime? _expectedDeliveryAt;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _shippingCodeController.dispose();
    _shippingProviderController.dispose();
    _expectedDeliveryController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'Thiếu access token';
      });
      return;
    }

    setState(() {
      _error = null;
    });

    try {
      final detail = await widget.dataSource.getOrderDetail(
        token,
        widget.orderCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _selectedStatus = '${detail['status'] ?? 'PENDING'}'.toUpperCase();
        _shippingCodeController.text = '${detail['shippingCode'] ?? ''}';
        _shippingProviderController.text =
            '${detail['shippingProvider'] ?? ''}';
        final rawExpected = '${detail['shippingExpectedDeliveryAt'] ?? ''}'
            .trim();
        if (rawExpected.isEmpty) {
          _expectedDeliveryAt = null;
          _expectedDeliveryController.clear();
        } else {
          final parsed = DateTime.tryParse(rawExpected);
          _expectedDeliveryAt = parsed;
          _expectedDeliveryController.text =
              parsed?.toIso8601String() ?? rawExpected;
        }
      });
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.message ?? 'Không thể tải chi tiết đơn hàng';
      });
    }
  }

  Future<void> _assignShipping() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final shippingCode = _shippingCodeController.text.trim();
    final shippingProvider = _shippingProviderController.text.trim();
    if (shippingCode.isEmpty || shippingProvider.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã vận đơn và đơn vị vận chuyển là bắt buộc.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await widget.dataSource.assignShipping(
        token,
        widget.orderCode,
        shippingCode: shippingCode,
        shippingProvider: shippingProvider,
        expectedDeliveryAt: _expectedDeliveryAt?.toIso8601String(),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = updated.isEmpty ? _detail : updated;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gán thông tin vận chuyển.')),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Không thể gán thông tin vận chuyển'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _pickExpectedDeliveryAt() async {
    final now = DateTime.now();
    final initial = _expectedDeliveryAt ?? now.add(const Duration(hours: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (pickedTime == null || !mounted) {
      return;
    }

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _expectedDeliveryAt = selected;
      _expectedDeliveryController.text = selected.toIso8601String();
    });
  }

  void _clearExpectedDeliveryAt() {
    setState(() {
      _expectedDeliveryAt = null;
      _expectedDeliveryController.clear();
    });
  }

  Future<void> _confirmCod() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await widget.dataSource.confirmCod(
        token,
        widget.orderCode,
        note: _noteController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = updated.isEmpty ? _detail : updated;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xác nhận COD.')));
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Không thể xác nhận COD')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveStatus() async {
    final token = widget.authController.session?.token;
    final status = _selectedStatus;

    if (token == null || token.isEmpty || status == null || status.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await widget.dataSource.updateOrderStatus(
        token,
        widget.orderCode,
        status: status,
        note: _noteController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _detail = updated.isEmpty ? _detail : updated;
        _selectedStatus = '${_detail?['status'] ?? status}'.toUpperCase();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật trạng thái đơn hàng thành công.'),
        ),
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Không thể cập nhật trạng thái đơn hàng'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      appBar: AppBar(title: Text('Đơn hàng ${widget.orderCode}')),
      bottomNavigationBar: detail == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: FilledButton.tonal(
                  onPressed: _isSaving ? null : _confirmCod,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Xác nhận COD'),
                ),
              ),
            ),
      body: _error != null
          ? Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : detail == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 88),
              children: [
                _block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Khách hàng',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      _infoRow(
                        icon: Icons.badge_outlined,
                        text:
                            '${detail['receiverName'] ?? detail['fullName'] ?? '--'}',
                        emphasize: true,
                      ),
                      const SizedBox(height: 6),
                      _infoRow(
                        icon: Icons.phone_rounded,
                        text: '${detail['receiverPhone'] ?? '--'}',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Giao hàng',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _infoRow(
                        icon: Icons.location_on_outlined,
                        text: '${detail['shippingAddress'] ?? '--'}',
                        small: true,
                      ),
                      const SizedBox(height: 12),
                      const Divider(
                        height: 1,
                        color: AppColors.surfaceContainerHighest,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.receipt_long_rounded,
                            color: AppColors.primaryContainer,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tổng tiền',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const Spacer(),
                          Text(
                            _formatMoney(
                              detail['totalAmount'] ??
                                  detail['grandTotal'] ??
                                  0,
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  color: AppColors.primaryContainer,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cập nhật trạng thái',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.surfaceContainerHighest.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          initialValue: _statuses.contains(_selectedStatus)
                              ? _selectedStatus
                              : _statuses.first,
                          decoration: _fieldDecoration(),
                          dropdownColor: AppColors.surfaceContainer,
                          items: _statuses
                              .map(
                                (status) => DropdownMenuItem<String>(
                                  value: status,
                                  child: Text(_statusLabel(status)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _selectedStatus = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteController,
                        minLines: 2,
                        maxLines: 4,
                        decoration: _fieldDecoration(
                          hintText: 'Ghi chú (không bắt buộc)',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.onPrimaryContainer,
                          ),
                          onPressed: _isSaving ? null : _saveStatus,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Cập nhật trạng thái'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _buildItems(),
                const SizedBox(height: 12),
                _block(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gán vận chuyển',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _shippingCodeController,
                        decoration: _fieldDecoration(hintText: 'Mã vận đơn'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _shippingProviderController,
                        decoration: _fieldDecoration(
                          hintText: 'Đơn vị vận chuyển',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _expectedDeliveryController,
                        readOnly: true,
                        onTap: _pickExpectedDeliveryAt,
                        decoration: _fieldDecoration(
                          hintText: 'Chọn ngày giờ giao dự kiến',
                          suffixIcon: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: _pickExpectedDeliveryAt,
                                icon: const Icon(Icons.schedule_rounded),
                                tooltip: 'Chọn ngày giờ',
                              ),
                              IconButton(
                                onPressed: _clearExpectedDeliveryAt,
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: 'Xóa',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppColors.primaryContainer,
                            ),
                            foregroundColor: AppColors.primaryContainer,
                          ),
                          onPressed: _isSaving ? null : _assignShipping,
                          child: const Text('Gán vận chuyển'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
    );
  }

  Widget _buildItems() {
    final rawItems = _detail!['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : const <Map<String, dynamic>>[];

    return _block(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sản phẩm',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            const Text('Không có chi tiết sản phẩm')
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final name = '${item['productName'] ?? 'N/A'}';
              final quantity = item['quantity'] ?? 0;
              final amount = item['lineAmount'] ?? item['unitPrice'] ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'x$quantity',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatMoney(amount),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (index != items.length - 1)
                      Divider(
                        height: 18,
                        color: AppColors.textSecondary.withValues(alpha: 0.2),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _block({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  InputDecoration _fieldDecoration({String? hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryContainer),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    bool emphasize = false,
    bool small = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryContainer, size: small ? 16 : 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: small ? 13 : (emphasize ? 16 : 14),
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    final format = NumberFormat.decimalPattern('vi_VN');
    return '${format.format(amount.round())}đ';
  }

  String _statusLabel(String value) {
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
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';
import '../widgets/admin_top_bar.dart';

class AdminPromotionsPage extends StatefulWidget {
  const AdminPromotionsPage({
    super.key,
    required this.authController,
    required this.dataSource,
  });

  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends State<AdminPromotionsPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _togglingIds = <String>{};

  late Future<AdminPageResult> _future;

  String _activeFilter = 'ALL';
  int _currentPage = 0;
  final int _pageSize = 10;
  int _totalPages = 1;
  int _totalElements = 0;

  List<Map<String, dynamic>> _filterItems(List<Map<String, dynamic>> items) {
    final keyword = _searchController.text.trim().toLowerCase();
    final normalizedKeyword = keyword.replaceAll(RegExp(r'\s+'), ' ');

    return items.where((item) {
      final matchesStatus = switch (_activeFilter) {
        'ACTIVE' => _isActive(item),
        'INACTIVE' => !_isActive(item),
        _ => true,
      };
      if (!matchesStatus) {
        return false;
      }

      if (normalizedKeyword.isEmpty) {
        return true;
      }

      final haystack = <String>[
        _code(item),
        _discountType(item),
        _discountText(item),
        '${item['id'] ?? ''}',
        '${item['minOrderValue'] ?? ''}',
        '${item['maxDiscountAmount'] ?? ''}',
        '${item['maxUsage'] ?? ''}',
      ].join(' ').toLowerCase();

      return haystack.contains(normalizedKeyword);
    }).toList();
  }

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

    final activeOnly = _activeFilter == 'ALL'
        ? null
        : _activeFilter == 'ACTIVE';

    final result = await widget.dataSource.getPromotions(
      token,
      page: _currentPage,
      size: _pageSize,
      activeOnly: activeOnly,
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

  String _promotionId(Map<String, dynamic> item) {
    return '${item['id'] ?? item['promotionId'] ?? ''}'.trim();
  }

  bool _isActive(Map<String, dynamic> item) {
    return item['isActive'] == true || item['active'] == true;
  }

  String _code(Map<String, dynamic> item) {
    final raw =
        '${item['code'] ?? item['voucherCode'] ?? item['name'] ?? 'N/A'}';
    return raw.trim().isEmpty ? 'N/A' : raw.trim();
  }

  String _discountType(Map<String, dynamic> item) {
    return '${item['discountType'] ?? 'PERCENTAGE'}'.toUpperCase();
  }

  num _numValue(dynamic input) {
    if (input is num) {
      return input;
    }
    return num.tryParse('$input') ?? 0;
  }

  String _money(dynamic input) {
    final value = _numValue(input);
    return '${NumberFormat.decimalPattern('vi_VN').format(value)}đ';
  }

  String _dateText(dynamic input) {
    final raw = '$input'.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') {
      return '--';
    }
    final dt = DateTime.tryParse(raw);
    if (dt == null) {
      return raw;
    }
    return DateFormat('HH:mm dd/MM/yyyy').format(dt.toLocal());
  }

  String _discountText(Map<String, dynamic> item) {
    final type = _discountType(item);
    final value = _numValue(item['discountValue']);
    if (type.contains('FREE_SHIP')) {
      return 'Miễn phí vận chuyển';
    }
    if (type.contains('PERCENT')) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}%';
    }
    return _money(value);
  }

  String _statusText(Map<String, dynamic> item) {
    return _isActive(item) ? 'Đang hoạt động' : 'Ngừng hoạt động';
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool nextValue) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = _promotionId(item);
    if (id.isEmpty || _togglingIds.contains(id)) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(nextValue ? 'Bật khuyến mãi' : 'Tắt khuyến mãi'),
            content: Text(
              'Bạn có chắc muốn ${nextValue ? 'bật' : 'tắt'} mã "${_code(item)}"?',
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

    if (!confirmed) {
      return;
    }

    setState(() {
      _togglingIds.add(id);
    });

    try {
      await widget.dataSource.updatePromotionActive(
        token,
        id,
        active: nextValue,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextValue ? 'Đã bật khuyến mãi' : 'Đã tắt khuyến mãi'),
        ),
      );
      _reload(page: _currentPage);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Cập nhật trạng thái thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _togglingIds.remove(id);
        });
      }
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final changed =
        await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surfaceContainer,
          builder: (_) => _PromotionEditorSheet(
            token: token,
            dataSource: widget.dataSource,
            existing: existing,
          ),
        ) ??
        false;

    if (changed) {
      _reload(page: _currentPage);
    }
  }

  Future<void> _deletePromotion(Map<String, dynamic> item) async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty) {
      return;
    }

    final id = _promotionId(item);
    if (id.isEmpty) {
      return;
    }

    final approved =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Xóa khuyến mãi'),
            content: Text('Bạn có chắc muốn xóa mã "${_code(item)}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Hủy'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
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
      await widget.dataSource.deletePromotion(token, id);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa khuyến mãi')));
      final targetPage = _currentPage > 0 && _totalElements == 1
          ? _currentPage - 1
          : _currentPage;
      _reload(page: targetPage);
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Xóa khuyến mãi thất bại')),
      );
    }
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final id = _promotionId(item);
    final active = _isActive(item);
    final usage = _numValue(item['currentUsage']).toInt();
    final maxUsageRaw = item['maxUsage'];
    final maxUsageText = maxUsageRaw == null
        ? 'Không giới hạn'
        : '$maxUsageRaw';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.greenAccent.withValues(alpha: 0.16)
                      : AppColors.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_offer_rounded,
                  color: active ? Colors.greenAccent : AppColors.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _code(item),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _openEditor(existing: item);
                  } else if (value == 'delete') {
                    _deletePromotion(item);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_discountType(item)} · ${_statusText(item)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _InfoChip(icon: Icons.percent_rounded, text: _discountText(item)),
              _InfoChip(
                icon: Icons.wallet_rounded,
                text: 'Tối thiểu: ${_money(item['minOrderValue'])}',
              ),
              if (_discountType(item).contains('PERCENT'))
                _InfoChip(
                  icon: Icons.money_off_csred_rounded,
                  text: 'Giảm tối đa: ${_money(item['maxDiscountAmount'])}',
                ),
              _InfoChip(
                icon: Icons.inventory_2_rounded,
                text: 'Lượt dùng: $usage / $maxUsageText',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Bắt đầu: ${_dateText(item['startDate'])}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            'Hết hạn: ${_dateText(item['expiryDate'])}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                active ? 'Đang hoạt động' : 'Ngừng hoạt động',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_togglingIds.contains(id))
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch.adaptive(
                  value: active,
                  onChanged: (value) => _toggleActive(item, value),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          _reload(page: _currentPage);
          await _future;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            AdminTopBar(
              title: 'QUẢN LÝ KHUYẾN MÃI',
              role: widget.authController.userRole ?? 'ADMIN',
              onLogout: () => widget.authController.logout(),
            ),
            const SizedBox(height: 12),
            FutureBuilder<AdminPageResult>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.hasData
                    ? snapshot.data!.items
                    : <Map<String, dynamic>>[];
                final activeCount = items.where(_isActive).length;
                final inactiveCount = items.length - activeCount;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 420;
                        final cardWidth = narrow
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 20) / 3;

                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _buildStatCard(
                                icon: Icons.local_offer_rounded,
                                label: 'Mã đang hiển thị',
                                value: '${items.length}',
                                accent: AppColors.primaryContainer,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildStatCard(
                                icon: Icons.check_circle_rounded,
                                label: 'Đang bật',
                                value: '$activeCount',
                                accent: Colors.lightGreenAccent,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _buildStatCard(
                                icon: Icons.pause_circle_rounded,
                                label: 'Đang tắt',
                                value: '$inactiveCount',
                                accent: Colors.orangeAccent,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer.withValues(
                          alpha: 0.78,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => setState(() {}),
                            onSubmitted: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Tìm theo mã, loại giảm, giá trị... ',
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
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final compact = constraints.maxWidth < 420;

                              if (compact) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    DropdownButtonFormField<String>(
                                      value: _activeFilter,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Trạng thái',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Text('Tất cả'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ACTIVE',
                                          child: Text('Đang hoạt động'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'INACTIVE',
                                          child: Text('Ngừng hoạt động'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _activeFilter = value;
                                        });
                                        _reload(page: 0);
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () => _openEditor(),
                                        icon: const Icon(Icons.add_rounded),
                                        label: const Text('Thêm mới'),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _activeFilter,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                        labelText: 'Trạng thái',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'ALL',
                                          child: Text('Tất cả'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'ACTIVE',
                                          child: Text('Đang hoạt động'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'INACTIVE',
                                          child: Text('Ngừng hoạt động'),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value == null) {
                                          return;
                                        }
                                        setState(() {
                                          _activeFilter = value;
                                        });
                                        _reload(page: 0);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: () => _openEditor(),
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Thêm mới'),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tìm kiếm đang áp dụng trên danh sách hiện tại của trang.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
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
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      snapshot.error?.toString() ??
                          'Không tải được dữ liệu khuyến mãi',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  );
                }

                final items = _filterItems(snapshot.data!.items);

                if (items.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 28),
                        const SizedBox(height: 8),
                        Text(
                          'Không có khuyến mãi phù hợp.',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hãy đổi từ khóa hoặc trạng thái để xem dữ liệu khác.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hiển thị ${items.length} / $_totalElements khuyến mãi',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...items.map(_buildCard),
                    const SizedBox(height: 6),
                    _Pager(
                      currentPage: _currentPage,
                      totalPages: _totalPages,
                      onChanged: (nextPage) => _reload(page: nextPage),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.currentPage,
    required this.totalPages,
    required this.onChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final atFirst = currentPage <= 0;
    final atLast = currentPage >= totalPages - 1;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: atFirst ? null : () => onChanged(currentPage - 1),
          icon: const Icon(Icons.chevron_left_rounded),
          label: const Text('Trước'),
        ),
        const Spacer(),
        Text('Trang ${currentPage + 1}/$totalPages'),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: atLast ? null : () => onChanged(currentPage + 1),
          icon: const Icon(Icons.chevron_right_rounded),
          label: const Text('Sau'),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primaryContainer),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _PromotionEditorSheet extends StatefulWidget {
  const _PromotionEditorSheet({
    required this.token,
    required this.dataSource,
    this.existing,
  });

  final String token;
  final AdminRemoteDataSource dataSource;
  final Map<String, dynamic>? existing;

  @override
  State<_PromotionEditorSheet> createState() => _PromotionEditorSheetState();
}

class _PromotionEditorSheetState extends State<_PromotionEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _discountValueController;
  late final TextEditingController _minOrderController;
  late final TextEditingController _maxDiscountController;
  late final TextEditingController _maxUsageController;

  String _discountType = 'PERCENTAGE';
  DateTime? _startDate;
  DateTime? _expiryDate;
  bool _isActive = true;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _codeController = TextEditingController(text: '${existing?['code'] ?? ''}');
    _discountValueController = TextEditingController(
      text: '${existing?['discountValue'] ?? ''}',
    );
    _minOrderController = TextEditingController(
      text: '${existing?['minOrderValue'] ?? ''}',
    );
    _maxDiscountController = TextEditingController(
      text: '${existing?['maxDiscountAmount'] ?? ''}',
    );
    _maxUsageController = TextEditingController(
      text: '${existing?['maxUsage'] ?? ''}',
    );

    final typeRaw = '${existing?['discountType'] ?? 'PERCENTAGE'}'
        .toUpperCase();
    _discountType = _normalizeDiscountType(typeRaw);

    _isActive = existing == null
        ? true
        : (existing['isActive'] == true || existing['active'] == true);

    _startDate = DateTime.tryParse('${existing?['startDate'] ?? ''}');
    _expiryDate = DateTime.tryParse('${existing?['expiryDate'] ?? ''}');
  }

  @override
  void dispose() {
    _codeController.dispose();
    _discountValueController.dispose();
    _minOrderController.dispose();
    _maxDiscountController.dispose();
    _maxUsageController.dispose();
    super.dispose();
  }

  String _normalizeDiscountType(String raw) {
    if (raw.contains('FREE')) {
      return 'FREE_SHIP';
    }
    if (raw.contains('FIXED') || raw.contains('AMOUNT')) {
      return 'FIXED_AMOUNT';
    }
    return 'PERCENTAGE';
  }

  num? _parseNum(String input) {
    final value = input.trim().replaceAll(',', '');
    if (value.isEmpty) {
      return null;
    }
    return num.tryParse(value);
  }

  int? _parseInt(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_expiryDate ?? DateTime.now().add(const Duration(days: 7)));

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (date == null || !mounted) {
      return;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null || !mounted) {
      return;
    }

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _expiryDate = picked;
      }
    });
  }

  String _dtText(DateTime? dt) {
    if (dt == null) {
      return 'Chưa chọn';
    }
    return DateFormat('HH:mm dd/MM/yyyy').format(dt);
  }

  Future<void> _submit() async {
    if (_submitting) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ngày bắt đầu và hết hạn')),
      );
      return;
    }

    if (_expiryDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngày hết hạn phải sau ngày bắt đầu')),
      );
      return;
    }

    final discountValue = _discountType == 'FREE_SHIP'
        ? 0
        : _parseNum(_discountValueController.text);

    final payload = <String, dynamic>{
      'code': _codeController.text.trim().toUpperCase(),
      'discountType': _discountType,
      'discountValue': discountValue,
      'minOrderValue': _parseNum(_minOrderController.text),
      'maxDiscountAmount': _parseNum(_maxDiscountController.text),
      'maxUsage': _parseInt(_maxUsageController.text),
      'startDate': _startDate!.toIso8601String(),
      'expiryDate': _expiryDate!.toIso8601String(),
      'isActive': _isActive,
    };

    payload.removeWhere((key, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    setState(() {
      _submitting = true;
    });

    try {
      if (_isEditing) {
        final id = '${widget.existing?['id'] ?? ''}'.trim();
        await widget.dataSource.updatePromotion(widget.token, id, payload);
      } else {
        await widget.dataSource.createPromotion(widget.token, payload);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'Đã cập nhật khuyến mãi' : 'Đã tạo khuyến mãi mới',
          ),
        ),
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'Lưu khuyến mãi thất bại')),
      );
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Material(
      color: AppColors.surfaceContainer,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Sửa khuyến mãi' : 'Thêm khuyến mãi mới',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Mã khuyến mãi *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Mã khuyến mãi không được để trống';
                      }
                      if (value.trim().length < 3) {
                        return 'Mã khuyến mãi tối thiểu 3 ký tự';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _discountType,
                    decoration: const InputDecoration(
                      labelText: 'Loại giảm giá *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'PERCENTAGE',
                        child: Text('PERCENTAGE'),
                      ),
                      DropdownMenuItem(
                        value: 'FIXED_AMOUNT',
                        child: Text('FIXED_AMOUNT'),
                      ),
                      DropdownMenuItem(
                        value: 'FREE_SHIP',
                        child: Text('FREE_SHIP'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _discountType = value;
                        if (_discountType == 'FREE_SHIP') {
                          _discountValueController.text = '0';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _discountValueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: _discountType != 'FREE_SHIP',
                    decoration: InputDecoration(
                      labelText: _discountType == 'PERCENTAGE'
                          ? 'Giá trị giảm (%) *'
                          : 'Giá trị giảm *',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_discountType == 'FREE_SHIP') {
                        return null;
                      }
                      final parsed = _parseNum(value ?? '');
                      if (parsed == null) {
                        return 'Giá trị giảm không hợp lệ';
                      }
                      if (parsed <= 0) {
                        return 'Giá trị giảm phải lớn hơn 0';
                      }
                      if (_discountType == 'PERCENTAGE' && parsed > 100) {
                        return 'Giảm theo phần trăm không vượt quá 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _minOrderController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Đơn tối thiểu',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _maxDiscountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Giảm tối đa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _maxUsageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Số lượt dùng tối đa',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(isStart: true),
                          icon: const Icon(Icons.event_available_rounded),
                          label: Text('Bắt đầu: ${_dtText(_startDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickDateTime(isStart: false),
                          icon: const Icon(Icons.event_busy_rounded),
                          label: Text('Hết hạn: ${_dtText(_expiryDate)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: (value) {
                      setState(() {
                        _isActive = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kích hoạt ngay'),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _isEditing
                                  ? Icons.save_rounded
                                  : Icons.add_rounded,
                            ),
                      label: Text(
                        _submitting
                            ? 'Đang lưu...'
                            : (_isEditing ? 'Lưu thay đổi' : 'Tạo khuyến mãi'),
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
  }
}

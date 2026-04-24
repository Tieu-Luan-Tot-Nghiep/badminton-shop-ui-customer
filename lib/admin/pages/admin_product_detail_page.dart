import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../presentation/manager/auth_controller.dart';
import '../datasources/admin_remote_data_source.dart';

class AdminProductDetailPage extends StatefulWidget {
  const AdminProductDetailPage({
    super.key,
    required this.product,
    required this.authController,
    required this.dataSource,
  });

  final Map<String, dynamic> product;
  final AuthController authController;
  final AdminRemoteDataSource dataSource;

  @override
  State<AdminProductDetailPage> createState() => _AdminProductDetailPageState();
}

class _AdminProductDetailPageState extends State<AdminProductDetailPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _variants = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _images = const <Map<String, dynamic>>[];

  String get _productId => '${widget.product['id'] ?? ''}'.trim();

  Future<void> _openEditProductDialog() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty || _productId.isEmpty) {
      return;
    }

    final nameController = TextEditingController(
      text: '${widget.product['name'] ?? ''}',
    );
    final shortController = TextEditingController(
      text: '${widget.product['shortDescription'] ?? ''}',
    );
    final descController = TextEditingController(
      text: '${widget.product['description'] ?? ''}',
    );
    final priceController = TextEditingController(
      text: '${widget.product['basePrice'] ?? widget.product['price'] ?? ''}',
    );

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sửa sản phẩm'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Tên sản phẩm'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: shortController,
                decoration: const InputDecoration(labelText: 'Mô tả ngắn'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Mô tả'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá cơ bản'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (ok != true) {
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      priceController.dispose();
      return;
    }

    final name = nameController.text.trim();
    final price = double.tryParse(priceController.text.trim());
    if (name.isEmpty || price == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tên và giá sản phẩm không hợp lệ.')),
        );
      }
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      priceController.dispose();
      return;
    }

    try {
      await widget.dataSource.updateProduct(token, _productId, {
        'name': name,
        'shortDescription': shortController.text.trim(),
        'description': descController.text.trim(),
        'basePrice': price,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        widget.product['name'] = name;
        widget.product['shortDescription'] = shortController.text.trim();
        widget.product['description'] = descController.text.trim();
        widget.product['basePrice'] = price;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật sản phẩm.')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cập nhật sản phẩm thất bại: $e')));
    } finally {
      nameController.dispose();
      shortController.dispose();
      descController.dispose();
      priceController.dispose();
    }
  }

  Future<void> _openAssetsManager() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty || _productId.isEmpty) {
      return;
    }

    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => _DetailProductAssetsSheet(
        dataSource: widget.dataSource,
        token: token,
        productId: _productId,
        productName:
            '${widget.product['name'] ?? widget.product['productName'] ?? 'Sản phẩm'}',
      ),
    );

    if (changed == true && mounted) {
      await _load();
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = widget.authController.session?.token;
    if (token == null || token.isEmpty || _productId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Thiếu dữ liệu sản phẩm hoặc token';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.dataSource.getProductVariants(token, _productId),
        widget.dataSource.getProductImages(token, _productId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _variants = results[0];
        _images = results[1];
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Không thể tải chi tiết sản phẩm: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
        normalized == 'active' ||
        normalized == 'enabled' ||
        normalized == 'on';
  }

  String _formatMoney(dynamic value) {
    final amount = value is num
        ? value.toDouble()
        : double.tryParse('$value') ?? 0;
    return '${NumberFormat.decimalPattern('vi_VN').format(amount.round())}đ';
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.surfaceContainerHighest.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name =
        '${widget.product['name'] ?? widget.product['productName'] ?? 'Sản phẩm'}';
    final active =
        _isTruthy(widget.product['isActive']) ||
        _isTruthy(widget.product['is_active']) ||
        _isTruthy(widget.product['active']);
    final price = widget.product['basePrice'] ?? widget.product['price'] ?? 0;
    final shortDesc = '${widget.product['shortDescription'] ?? ''}'.trim();
    final desc = '${widget.product['description'] ?? ''}'.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _sectionCard(
                title: 'Lỗi tải dữ liệu',
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              )
            else ...[
              _sectionCard(
                title: 'Thông tin sản phẩm',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatMoney(price),
                      style: const TextStyle(
                        color: AppColors.primaryContainer,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID: $_productId',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
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
                        Text(active ? 'Đang hoạt động' : 'Đang tắt'),
                      ],
                    ),
                    if (shortDesc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Mô tả ngắn: $shortDesc'),
                    ],
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Mô tả: $desc'),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openEditProductDialog,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Sửa sản phẩm'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _openAssetsManager,
                            icon: const Icon(Icons.layers_outlined),
                            label: const Text('Quản lý biến thể/ảnh'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _sectionCard(
                title: 'Danh sách biến thể (${_variants.length})',
                child: _variants.isEmpty
                    ? const Text(
                        'Chưa có biến thể',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    : Column(
                        children: _variants.map((variant) {
                          final sku = '${variant['sku'] ?? 'N/A'}';
                          final size = '${variant['size'] ?? '--'}';
                          final color = '${variant['color'] ?? '--'}';
                          final stock = '${variant['stock'] ?? 0}';
                          final variantPrice = variant['price'] ?? 0;

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SKU: $sku',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('Kích thước: $size | Màu: $color'),
                                const SizedBox(height: 2),
                                Text(
                                  'Giá: ${_formatMoney(variantPrice)} | Tồn kho: $stock',
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              _sectionCard(
                title: 'Danh sách hình ảnh (${_images.length})',
                child: _images.isEmpty
                    ? const Text(
                        'Chưa có hình ảnh',
                        style: TextStyle(color: AppColors.textSecondary),
                      )
                    : GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _images.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                        itemBuilder: (context, index) {
                          final image = _images[index];
                          final url =
                              '${image['imageUrl'] ?? image['url'] ?? ''}'
                                  .trim();
                          final isMain = image['isMain'] == true;

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: AppColors.surfaceContainerLow),
                                if (url.isNotEmpty)
                                  Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.textSecondary,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.image_not_supported_outlined,
                                    color: AppColors.textSecondary,
                                  ),
                                if (isMain)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: const Text(
                                        'Ảnh chính',
                                        style: TextStyle(
                                          color: AppColors.onPrimaryContainer,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailProductAssetsSheet extends StatefulWidget {
  const _DetailProductAssetsSheet({
    required this.dataSource,
    required this.token,
    required this.productId,
    required this.productName,
  });

  final AdminRemoteDataSource dataSource;
  final String token;
  final String productId;
  final String productName;

  @override
  State<_DetailProductAssetsSheet> createState() =>
      _DetailProductAssetsSheetState();
}

class _DetailProductAssetsSheetState extends State<_DetailProductAssetsSheet> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = true;
  bool _changed = false;
  List<Map<String, dynamic>> _variants = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _images = const <Map<String, dynamic>>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final results = await Future.wait([
        widget.dataSource.getProductVariants(widget.token, widget.productId),
        widget.dataSource.getProductImages(widget.token, widget.productId),
      ]);

      if (!mounted) {
        return;
      }

      setState(() {
        _variants = results[0];
        _images = results[1];
      });
    } catch (_) {
      // Keep sheet visible with empty state.
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    final id = '${variant['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.deleteProductVariant(
        widget.token,
        widget.productId,
        id,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _openVariantEditor({Map<String, dynamic>? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainer,
      builder: (context) => _DetailVariantEditorSheet(
        dataSource: widget.dataSource,
        token: widget.token,
        productId: widget.productId,
        existing: existing,
      ),
    );

    if (changed == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final id = '${image['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    try {
      await widget.dataSource.deleteProductImage(
        widget.token,
        widget.productId,
        id,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _editImageMeta(Map<String, dynamic> image) async {
    final id = '${image['id'] ?? ''}'.trim();
    if (id.isEmpty) {
      return;
    }

    final colorController = TextEditingController(
      text: '${image['color'] ?? ''}',
    );
    bool isMain = image['isMain'] == true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Sửa thông tin ảnh'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Màu'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ảnh chính'),
                value: isMain,
                onChanged: (value) {
                  setLocal(() {
                    isMain = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) {
      colorController.dispose();
      return;
    }

    try {
      await widget.dataSource.updateProductImage(
        widget.token,
        widget.productId,
        id,
        {'color': colorController.text.trim(), 'isMain': isMain},
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      colorController.dispose();
    }
  }

  Future<void> _uploadImage() async {
    final colorController = TextEditingController();
    bool isMain = false;

    final ready = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Tải ảnh sản phẩm lên'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: colorController,
                decoration: const InputDecoration(
                  labelText: 'Màu (không bắt buộc)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ảnh chính'),
                value: isMain,
                onChanged: (value) {
                  setLocal(() {
                    isMain = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      ),
    );

    if (ready != true) {
      colorController.dispose();
      return;
    }

    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) {
      colorController.dispose();
      return;
    }

    try {
      await widget.dataSource.uploadProductImage(
        widget.token,
        widget.productId,
        filePath: picked.path,
        color: colorController.text.trim().isEmpty
            ? null
            : colorController.text.trim(),
        isMain: isMain,
      );
      _changed = true;
      await _load();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      colorController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tài nguyên: ${widget.productName}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Biến thể (${_variants.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: () => _openVariantEditor(),
                          child: const Text('Thêm biến thể'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._variants.map((variant) {
                      final variantId = '${variant['id'] ?? ''}';
                      final sku = '${variant['sku'] ?? ''}';
                      final size = '${variant['size'] ?? ''}';
                      final color = '${variant['color'] ?? ''}';
                      final price = '${variant['price'] ?? 0}';
                      final stock = '${variant['stock'] ?? 0}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: $variantId | SKU: $sku'),
                            const SizedBox(height: 4),
                            Text(
                              'Kích thước: $size | Màu: $color | Giá: $price | Tồn kho: $stock',
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () =>
                                      _openVariantEditor(existing: variant),
                                  child: const Text('Sửa'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteVariant(variant),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Hình ảnh (${_images.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        OutlinedButton(
                          onPressed: _uploadImage,
                          child: const Text('Tải ảnh lên'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ..._images.map((image) {
                      final url = '${image['imageUrl'] ?? image['url'] ?? ''}';
                      final color = '${image['color'] ?? ''}';
                      final isMain = image['isMain'] == true;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (url.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url,
                                  height: 120,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const SizedBox(
                                    height: 120,
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 6),
                            Text('Màu: $color | Ảnh chính: $isMain'),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _editImageMeta(image),
                                  child: const Text('Sửa thông tin ảnh'),
                                ),
                                OutlinedButton(
                                  onPressed: () => _deleteImage(image),
                                  child: const Text('Xóa'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(_changed),
              child: const Text('Xong'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailVariantEditorSheet extends StatefulWidget {
  const _DetailVariantEditorSheet({
    required this.dataSource,
    required this.token,
    required this.productId,
    this.existing,
  });

  final AdminRemoteDataSource dataSource;
  final String token;
  final String productId;
  final Map<String, dynamic>? existing;

  @override
  State<_DetailVariantEditorSheet> createState() =>
      _DetailVariantEditorSheetState();
}

class _DetailVariantEditorSheetState extends State<_DetailVariantEditorSheet> {
  final _skuController = TextEditingController();
  final _weightController = TextEditingController();
  final _gripController = TextEditingController();
  final _stiffnessController = TextEditingController();
  final _balancePointController = TextEditingController();
  final _sizeController = TextEditingController();
  final _colorController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _skuController.text = '${existing['sku'] ?? ''}';
      _weightController.text = '${existing['weight'] ?? ''}';
      _gripController.text = '${existing['gripSize'] ?? ''}';
      _stiffnessController.text = '${existing['stiffness'] ?? ''}';
      _balancePointController.text = '${existing['balancePoint'] ?? ''}';
      _sizeController.text = '${existing['size'] ?? ''}';
      _colorController.text = '${existing['color'] ?? ''}';
      _priceController.text = '${existing['price'] ?? ''}';
      _stockController.text = '${existing['stock'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _skuController.dispose();
    _weightController.dispose();
    _gripController.dispose();
    _stiffnessController.dispose();
    _balancePointController.dispose();
    _sizeController.dispose();
    _colorController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final sku = _skuController.text.trim();
    final size = _sizeController.text.trim();
    final color = _colorController.text.trim();
    final price = double.tryParse(_priceController.text.trim());
    final stock = int.tryParse(_stockController.text.trim());

    if (sku.isEmpty ||
        size.isEmpty ||
        color.isEmpty ||
        price == null ||
        stock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SKU, kích thước, màu, giá và tồn kho là bắt buộc.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final payload = <String, dynamic>{
      'sku': sku,
      'weight': _weightController.text.trim(),
      'gripSize': _gripController.text.trim(),
      'stiffness': _stiffnessController.text.trim(),
      'balancePoint': _balancePointController.text.trim(),
      'size': size,
      'color': color,
      'price': price,
      'stock': stock,
    };

    try {
      if (_isEdit) {
        final variantId = '${widget.existing?['id'] ?? ''}';
        await widget.dataSource.updateProductVariant(
          widget.token,
          widget.productId,
          variantId,
          payload,
        );
      } else {
        await widget.dataSource.createProductVariant(
          widget.token,
          widget.productId,
          payload,
        );
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
        SnackBar(content: Text(e.message ?? 'Lưu biến thể thất bại')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isEdit ? 'Sửa biến thể' : 'Tạo biến thể',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: 'SKU',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Kích thước',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _colorController,
              decoration: const InputDecoration(
                labelText: 'Màu',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Giá',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stockController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tồn kho',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _weightController,
              decoration: const InputDecoration(
                labelText: 'Trọng lượng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _gripController,
              decoration: const InputDecoration(
                labelText: 'Cỡ cán',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _stiffnessController,
              decoration: const InputDecoration(
                labelText: 'Độ cứng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _balancePointController,
              decoration: const InputDecoration(
                labelText: 'Điểm cân bằng',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEdit ? 'Lưu thay đổi' : 'Tạo biến thể'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

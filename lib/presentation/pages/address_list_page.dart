import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/entities/address_entity.dart';
import '../manager/address_controller.dart';
import '../manager/auth_controller.dart';
import 'address_form_page.dart';

class AddressListPage extends StatefulWidget {
  const AddressListPage({
    super.key,
    required this.controller,
    required this.authController,
    this.onNavigateToHome,
    this.selectionMode = false,
  });

  final AddressController controller;
  final AuthController authController;
  final VoidCallback? onNavigateToHome;
  /// When true, tapping an address returns it as a pop result.
  final bool selectionMode;

  @override
  State<AddressListPage> createState() => _AddressListPageState();
}

class _AddressListPageState extends State<AddressListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.loadAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _buildTopBar(context),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.controller,
                builder: (context, _) {
                  if (widget.controller.isLoading && widget.controller.addresses.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.primaryContainer));
                  }

                  if (widget.controller.errorMessage != null && widget.controller.addresses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(widget.controller.errorMessage!, style: const TextStyle(color: AppColors.textSecondary)),
                          TextButton(onPressed: widget.controller.loadAddresses, child: const Text('THỬ LẠI')),
                        ],
                      ),
                    );
                  }

                  if (widget.controller.addresses.isEmpty) {
                    return const Center(
                      child: Text('Bạn chưa thêm địa chỉ nào.', style: TextStyle(color: AppColors.textSecondary)),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: widget.controller.loadAddresses,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: widget.controller.addresses.length,
                      itemBuilder: (context, index) {
                        final address = widget.controller.addresses[index];
                        return _buildAddressCard(address);
                      },
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

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: widget.onNavigateToHome,
          child: Text(
            'SHUTTLE_X',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddressFormPage(controller: widget.controller)),
          ),
          icon: const Icon(Icons.add_rounded, color: AppColors.primaryContainer, size: 30),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHighest,
          backgroundImage: widget.authController.userProfile?.avatar != null
              ? NetworkImage(widget.authController.userProfile!.avatar!)
              : null,
          child: widget.authController.userProfile?.avatar == null
              ? const Icon(Icons.person_rounded, color: AppColors.textSecondary, size: 20)
              : null,
        ),
      ],
    );
  }

  Widget _buildAddressCard(AddressEntity address) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: address.isDefault
            ? Border.all(color: AppColors.primaryContainer, width: 2)
            : Border.all(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    address.receiverName.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'MẶC ĐỊNH',
                      style: TextStyle(color: AppColors.onPrimaryContainer, fontSize: 10, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address.phoneNumber,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Text(
              '${address.specificAddress}, ${address.ward}, ${address.district}, ${address.province}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.4),
            ),
            const Divider(height: 32, color: AppColors.outlineVariant),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (widget.selectionMode) ...
                  [
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(address),
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                      label: const Text('CHỌN ĐỊA CHỈ NÀY',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryContainer,
                        foregroundColor: AppColors.onPrimaryContainer,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]
                else ...
                  [
                    _buildActionButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.primaryContainer,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AddressFormPage(
                                controller: widget.controller, address: address)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                      onTap: () => _confirmDelete(address.id),
                    ),
                    if (!address.isDefault) ...[
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () =>
                            widget.controller.setDefaultAddress(address.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.primaryContainer,
                          elevation: 0,
                          side: const BorderSide(color: AppColors.primaryContainer),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('ĐẶT MẶC ĐỊNH',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final delete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerHighest,
        title: const Text('XÁC NHẬN XÓA'),
        content: const Text('Bạn có chắc muốn xóa địa chỉ này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('HỦY')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('XÓA'),
          ),
        ],
      ),
    );

    if (delete == true) {
      widget.controller.deleteAddress(id);
    }
  }
}

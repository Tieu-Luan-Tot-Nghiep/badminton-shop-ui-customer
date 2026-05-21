import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../manager/auth_controller.dart';
import '../manager/address_controller.dart';
import '../manager/order_controller.dart';
import '../widgets/cart_icon_bubble.dart';
import '../widgets/chat_icon_bubble.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';
import 'address_list_page.dart';
import 'order_history_page.dart';
import 'membership_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    required this.addressController,
    required this.orderController,
    required this.cartCountListenable,
    this.chatCountListenable,
    this.onOpenCart,
    this.onOpenChat,
    required this.onLoggedOut,
    this.onNavigateToHome,
  });

  final AuthController controller;
  final AddressController addressController;
  final OrderController orderController;
  final ValueListenable<int> cartCountListenable;
  final ValueListenable<int>? chatCountListenable;
  final VoidCallback? onOpenCart;
  final VoidCallback? onOpenChat;
  final VoidCallback onLoggedOut;
  final VoidCallback? onNavigateToHome;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final profile = controller.userProfile;
        final name =
            (profile?.fullName ?? controller.session?.username ?? 'NGƯỜI DÙNG')
                .toUpperCase();
        final rank = _toRankLabel(profile?.role ?? controller.session?.role);
        final avatarUrl = profile?.avatar;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 22),
            _buildAvatarSection(context, name, rank, avatarUrl),
            const SizedBox(height: 26),
            _buildSectionHeader(context, 'TÀI KHOẢN', 'Quản lý'),
            const SizedBox(height: 12),
            _buildActionTile(
              context,
              icon: Icons.person_rounded,
              title: 'THÔNG TIN TÀI KHOẢN',
              subtitle: 'Thông tin cá nhân & Liên hệ',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfilePage(
                    controller: controller,
                    onNavigateToHome: onNavigateToHome,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildActionTile(
              context,
              icon: Icons.location_on_rounded,
              title: 'QUẢN LÝ ĐỊA CHỈ',
              subtitle: 'Địa chỉ nhận hàng',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddressListPage(
                    controller: addressController,
                    authController: controller,
                    onNavigateToHome: onNavigateToHome,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildActionTile(
              context,
              icon: Icons.security_rounded,
              title: 'ĐỔI MẬT KHẨU',
              subtitle: 'Cập nhật bảo mật',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordPage(
                    controller: controller,
                    onNavigateToHome: onNavigateToHome,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildActionTile(
              context,
              icon: Icons.receipt_long_rounded,
              title: 'LỊCH SỬ ĐƠN HÀNG',
              subtitle: 'Theo dõi đơn hàng & Lịch sử',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderHistoryPage(
                    controller: orderController,
                    authController: controller,
                    onNavigateToHome: onNavigateToHome,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            _buildActionTile(
              context,
              icon: Icons.card_membership_rounded,
              title: 'TÍCH ĐIỂM THÀNH VIÊN',
              subtitle: 'Điểm thưởng & Quyền lợi',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MembershipPage(
                    authController: controller,
                    onNavigateToHome: onNavigateToHome,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 28),
            _buildSectionHeader(context, 'HỆ THỐNG', 'Bảo mật'),
            const SizedBox(height: 12),
            _buildLogoutButton(context),
          ],
        );
      },
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onNavigateToHome,
          child: Text(
            'SHUTTLE_X',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: AppColors.primaryContainer,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
        const Spacer(),
        if (chatCountListenable != null)
          ValueListenableBuilder<int>(
            valueListenable: chatCountListenable!,
            builder: (_, count, __) {
              return ChatIconBubble(count: count, onTap: onOpenChat);
            },
          )
        else
          ChatIconBubble(count: 0, onTap: onOpenChat),
        const SizedBox(width: 10),
        ValueListenableBuilder<int>(
          valueListenable: cartCountListenable,
          builder: (_, count, __) {
            return CartIconBubble(count: count, onTap: onOpenCart);
          },
        ),
        const SizedBox(width: 10),
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHighest,
          backgroundImage: controller.userProfile?.avatar != null
              ? NetworkImage(controller.userProfile!.avatar!)
              : null,
          child: controller.userProfile?.avatar == null
              ? const Icon(
                  Icons.person_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    String action,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic),
          ),
        ),
        Text(
          action,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: AppColors.primaryContainer),
        ),
      ],
    );
  }

  Widget _buildAvatarSection(
    BuildContext context,
    String name,
    String rank,
    String? avatarUrl,
  ) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(36),
                image: avatarUrl != null && avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(
                      Icons.account_circle_rounded,
                      size: 138,
                      color: Color(0xFF394252),
                    )
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.tertiary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 16,
                color: AppColors.surfaceDim,
              ),
              const SizedBox(width: 8),
              Text(
                rank,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.surfaceDim,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: AppColors.surfaceContainerLow.withValues(alpha: 0.95),
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.secondary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: AppColors.secondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
              size: 30,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      height: 74,
      child: ElevatedButton.icon(
        onPressed: () => _showLogoutConfirmation(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD02A00),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(37),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 30),
        label: Text(
          'ĐĂNG XUẤT',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final bool? shouldLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: const Text(
            'XÁC NHẬN ĐĂNG XUẤT',
            style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white),
          ),
          content: const Text(
            'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'HỦY',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD02A00),
              ),
              child: const Text(
                'ĐĂNG XUẤT',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      controller.logout();
      controller.clearMessages();
      onLoggedOut();
    }
  }

  String _toRankLabel(String? role) {
    final value = role?.toUpperCase().trim();
    if (value == null || value.isEmpty) {
      return 'HẠNG GOLD';
    }
    return 'HẠNG $value';
  }
}

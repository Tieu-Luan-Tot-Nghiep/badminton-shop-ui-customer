import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.dashboard_rounded, label: 'TỔNG QUAN'),
    (icon: Icons.receipt_long_rounded, label: 'ĐƠN HÀNG'),
    (icon: Icons.inventory_2_rounded, label: 'SẢN PHẨM'),
    (icon: Icons.assignment_return_rounded, label: 'ĐỔI TRẢ'),
    (icon: Icons.groups_rounded, label: 'NGƯỜI DÙNG'),
    (icon: Icons.settings_rounded, label: 'HỆ THỐNG'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final compactNav = screenWidth < 430;

    return Scaffold(
      body: Stack(
        children: [
          const _AdminBackground(),
          SafeArea(child: body),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compactNav ? 8 : 14,
            0,
            compactNav ? 8 : 14,
            12,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compactNav ? 4 : 8,
                  vertical: compactNav ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest.withValues(
                    alpha: 0.72,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.surfaceContainerHighest.withValues(alpha: 0.82),
                      AppColors.surfaceContainer.withValues(alpha: 0.76),
                    ],
                  ),
                ),
                child: Row(
                  children: List.generate(_items.length, (index) {
                    final selected = selectedIndex == index;
                    final item = _items[index];

                    return Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onTabChanged(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsets.symmetric(
                            vertical: compactNav ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryContainer.withValues(
                                    alpha: 0.12,
                                  )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: selected
                                    ? AppColors.primaryContainer
                                    : AppColors.textSecondary,
                                size: compactNav ? 19 : 21,
                              ),
                              SizedBox(height: compactNav ? 2 : 3),
                              Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontSize: compactNav ? 9.5 : 10.5,
                                      letterSpacing: compactNav ? 0.2 : 0.4,
                                      color: selected
                                          ? AppColors.primaryContainer
                                          : AppColors.textSecondary,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected
                                      ? AppColors.primaryContainer
                                      : Colors.transparent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminBackground extends StatelessWidget {
  const _AdminBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF051730), AppColors.surfaceDim, Color(0xFF021026)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -70,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.10),
                    blurRadius: 90,
                    spreadRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.08),
                    blurRadius: 88,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  final Widget body;
  final int selectedIndex;
  final ValueChanged<int> onTabChanged;

  static const _items = <({IconData icon, String label})>[
    (icon: Icons.home_rounded, label: 'HOME'),
    (icon: Icons.shopping_bag_outlined, label: 'SHOP'),
    (icon: Icons.center_focus_strong, label: 'SCAN'),
    (icon: Icons.rate_review_outlined, label: 'ĐÁNH GIÁ'),
    (icon: Icons.person_outline, label: 'HỒ SƠ'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _CyberBackground(),
          SafeArea(child: body),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
                          duration: const Duration(milliseconds: 240),
                          curve: Curves.easeOutCubic,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: selected
                                    ? AppColors.onPrimaryContainer
                                    : AppColors.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: selected
                                          ? AppColors.onPrimaryContainer
                                          : AppColors.textSecondary,
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

class _CyberBackground extends StatelessWidget {
  const _CyberBackground();

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
            top: -100,
            right: -60,
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
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 300,
            left: -120,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withValues(alpha: 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.05),
                    blurRadius: 80,
                    spreadRadius: 4,
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

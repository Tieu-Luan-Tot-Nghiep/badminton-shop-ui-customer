import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class TemplatePage extends StatelessWidget {
  const TemplatePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      children: [
        Text(title, style: Theme.of(context).textTheme.displayLarge),
        const SizedBox(height: 12),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: AppColors.surfaceContainer,
          ),
          child: Column(
            children: [
              Icon(icon, size: 52, color: AppColors.secondary),
              const SizedBox(height: 16),
              Text(
                'Screen template ready',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Màn hình này đang dùng cùng layout nền, spacing và bottom nav như Home để đồng bộ toàn app.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_colors.dart';

class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.iconAsset,
    this.onTap,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 92,
        child: Column(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.06),
                    blurRadius: 24,
                  ),
                ],
              ),
                child: Center(
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 30,
                    height: 30,
                    colorFilter: const ColorFilter.mode(
                      AppColors.primaryContainer,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
            ),
            const SizedBox(height: 10),
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

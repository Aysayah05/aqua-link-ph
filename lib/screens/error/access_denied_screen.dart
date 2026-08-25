import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';

class AccessDeniedScreen extends StatelessWidget {
  const AccessDeniedScreen({super.key, required this.expectedRole});
  final String? expectedRole;

  @override
  Widget build(BuildContext context) {
    final String? expected = expectedRole;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.gpp_bad_outlined, color: AppColors.danger, size: 42),
            ),
            const SizedBox(height: 20),
            Text('Access denied', style: AppTextStyles.h1),
            const SizedBox(height: 8),
            Text(
              expected == null
                  ? 'You do not have permission to open that portal.'
                  : 'This portal is restricted to ${Roles.label(expected)} accounts only.',
              textAlign: TextAlign.center,
              style: AppTextStyles.muted,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to my portal'),
            ),
          ],
        ),
      ),
    );
  }
}

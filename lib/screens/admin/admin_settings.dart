import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/seed_service.dart';
import '../../widgets/common_widgets.dart';

class AdminSettings extends StatelessWidget {
  const AdminSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Station profile', style: AppTextStyles.h3),
              const SizedBox(height: 12),
              InfoRow(label: 'System', value: AppConstants.appName, icon: Icons.apps_rounded),
              InfoRow(label: 'Business', value: AppConstants.stationName, icon: Icons.storefront_outlined),
              InfoRow(label: 'Address', value: AppConstants.stationAddress, icon: Icons.location_on_outlined),
              InfoRow(label: 'Contact', value: AppConstants.stationPhone, icon: Icons.call_outlined),
              InfoRow(label: 'Hours', value: AppConstants.stationHours, icon: Icons.schedule_outlined),
              InfoRow(label: 'Signed in as', value: '${auth.profile?.name} (${Roles.label(auth.profile?.role ?? '')})', icon: Icons.account_circle_outlined),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.science_outlined, size: 20, color: AppColors.accent),
                const SizedBox(width: 8),
                Text('Defense demo data', style: AppTextStyles.h3),
              ]),
              const SizedBox(height: 8),
              Text(
                  'Populate the system with realistic demo data for your capstone presentation:\n'
                  'products & inventory · customers · ~90 orders and sales across 35 days · 30 QR gallons in various states · expenses.\n\n'
                  'Demo accounts created (password Aqua123!):\n'
                  'staff@aquaph.test (Staff) · maria@aquaph.test (Customer)',
                  style: AppTextStyles.muted),
              const SizedBox(height: 16),
              _SeedButton(),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.cloud_done_outlined, size: 20, color: AppColors.success),
                const SizedBox(width: 8),
                Text('Deployment', style: AppTextStyles.h3),
              ]),
              const SizedBox(height: 10),
              Text('Build a production bundle and deploy to Firebase Hosting:', style: AppTextStyles.muted),
              const SizedBox(height: 10),
              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                  child: Text('flutter build web --release\nfirebase deploy --only hosting', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: AppColors.accent))),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SeedButton extends StatefulWidget {
  @override
  State<_SeedButton> createState() => _SeedButtonState();
}

class _SeedButtonState extends State<_SeedButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _busy ? null : () => _seed(context),
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      icon: _busy
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          : const Icon(Icons.auto_awesome_rounded, size: 18),
      label: Text(_busy ? 'Seeding demo data…' : 'Generate demo data'),
    );
  }

  Future<void> _seed(BuildContext context) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Generate demo data',
      message: 'This writes sample products, customers, orders, sales, gallons and expenses to Firestore. It skips automatically if orders already exist. Continue?',
      confirmLabel: 'Generate',
    );
    if (!ok || !context.mounted) return;
    setState(() => _busy = true);
    final SeedResult result =
        await SeedService().seedAll();
    if (!context.mounted) return;
    setState(() => _busy = false);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.success ? 'Demo data ready' : 'Notice'),
        content: SingleChildScrollView(child: Text(result.message)),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/app_notification_model.dart';
import '../../models/inventory_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/common_widgets.dart';
import 'customer_new_order.dart';

class CustomerHome extends StatelessWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
      _hero(context, auth),
      const SizedBox(height: 14),
      const _NearArrivalBanner(),
      const SizedBox(height: 14),
      Text('Water products & prices', style: AppTextStyles.h3),
      const SizedBox(height: 8),
      StreamBuilder<List<InventoryItemModel>>(
        stream: InventoryService().streamItems(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!.where((p) => p.category == 'Refill').toList();
          if (items.isEmpty) return Text('Product list is being prepared.', style: AppTextStyles.muted);
          return Column(children: items.map((p) => Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(width: 38, height: 38, decoration:
                BoxDecoration(color: AppColors.primary.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 20)),
              title: Text(p.name, style: AppTextStyles.bodyStrong),
              subtitle: Text(p.quantityOnHand <= 0 ? 'Currently unavailable' : 'In stock', style: AppTextStyles.caption.copyWith(
                  color: p.quantityOnHand <= 0 ? AppColors.danger : AppColors.success)),
              trailing: Text(AppFormatters.peso(p.unitPrice), style: AppTextStyles.h3.copyWith(color: AppColors.accent)),
            ),
          )).toList());
        },
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: 'How ordering works'),
          const SizedBox(height: 12),
          ..._steps.map((s) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 24, height: 24,
                decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${_steps.indexOf(s) + 1}', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(child: Text(s, style: AppTextStyles.body)),
            ]),
          )),
        ])),
      ),
      const SizedBox(height: 14),
      Card(
        child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(title: 'Station information'),
          const SizedBox(height: 10),
          InfoRow(label: 'Business', value: AppConstants.stationName),
          InfoRow(label: 'Address', value: AppConstants.stationAddress),
          InfoRow(label: 'Contact', value: AppConstants.stationPhone),
          InfoRow(label: 'Hours', value: AppConstants.stationHours),
          InfoRow(label: 'Delivery fee', value: '${AppFormatters.peso(AppConstants.deliveryFee)} per order'),
        ])),
      ),
    ]);
  }

  static const List<String> _steps = [
    'Choose a water product and the number of gallons you need.',
    'Submit your delivery request — it is recorded instantly.',
    'Staff confirms your order and prepares your gallons.',
    'Each gallon is scanned and tracked by QR from the station to you.',
    'Receive a near-arrival notification when the driver is close.',
    'Pay on delivery (cash or GCash). Return empty gallons for refill.',
  ];

  Widget _hero(BuildContext context, AuthProvider auth) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primarySoft, AppColors.surface]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Hi ${((auth.profile?.name ?? '').split(' ')).first}! 💧', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text('Fresh purified, distilled and alkaline water delivered to your door.',
                style: AppTextStyles.muted),
          ])),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerNewOrderPage())),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: AppColors.background),
          icon: const Icon(Icons.water_drop_rounded, size: 19),
          label: const Text('Order water now'),
        ),
      ]),
    );
  }
}

class _NearArrivalBanner extends StatelessWidget {
  const _NearArrivalBanner();

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    if (!auth.isSignedIn) return const SizedBox.shrink();
    final String uid = auth.profile!.uid;
    return StreamBuilder<List<AppNotification>>(
      stream: NotificationService().streamForUser(uid),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) return const SizedBox.shrink();
        final AppNotification latest =
            snap.data!.where((n) => !n.read && n.type == 'near_arrival').first;
        final bool fresh = latest.createdAt != null &&
            DateTime.now().difference(latest.createdAt!) < const Duration(hours: 6);
        if (!fresh) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.1),
            border: Border.all(color: AppColors.warning.withOpacity(0.5)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(Icons.near_me_rounded, color: AppColors.warning, size: 22),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(latest.title, style: AppTextStyles.bodyStrong),
              Text(latest.body, style: AppTextStyles.muted),
            ])),
          ]),
        );
      },
    );
  }
}

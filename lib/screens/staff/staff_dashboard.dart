import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/gallon_model.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';
import '../shared/order_details_dialog.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Text('Station operations today', style: AppTextStyles.h1.copyWith(fontSize: 22)),
      const SizedBox(height: 2),
      Text(AppFormatters.date(DateTime.now()), style: AppTextStyles.muted),
      const SizedBox(height: 18),
      StreamBuilder<List<OrderModel>>(
          stream: OrderService().streamOrders(),
          builder: (context, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator());
            final List<OrderModel> orders = snap.data!;
            int pending = 0, preparing = 0, transit = 0, unpaid = 0;
            for (final OrderModel o in orders) {
              switch (o.status) {
                case OrderStatus.pending:
                  pending++;
                  break;
                case OrderStatus.confirmed:
                case OrderStatus.preparing:
                  preparing++;
                  break;
                case OrderStatus.inTransit:
                  transit++;
                  break;
              }
              if (o.paymentStatus == PaymentStatus.unpaid &&
                  (o.status == OrderStatus.inTransit || o.status == OrderStatus.delivered)) {
                unpaid++;
              }
            }
            return LayoutBuilder(builder: (context, c) {
              final int cols = c.maxWidth > 950 ? 4 : 2;
              return GridView.count(
                crossAxisCount: cols,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 132,
                children: [
                  StatCard(label: 'New orders to review', value: '$pending', icon: Icons.notifications_active_rounded, color: AppColors.warning),
                  StatCard(label: 'Being prepared', value: '$preparing', icon: Icons.water_rounded, color: AppColors.primary),
                  StatCard(label: 'Out for delivery', value: '$transit', icon: Icons.local_shipping_rounded, color: AppColors.accent),
                  StatCard(label: 'Payments to verify', value: '$unpaid', icon: Icons.fact_check_rounded, color: unpaid > 0 ? AppColors.danger : AppColors.success),
                ],
              );
            });
          }),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Incoming queue'),
            const SizedBox(height: 6),
            StreamBuilder<List<OrderModel>>(
              stream: OrderService().streamOrders(status: OrderStatus.pending),
              builder: (context, snap) {
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                final List<OrderModel> pending = snap.data!.take(8).toList();
                if (pending.isEmpty) {
                  return const EmptyState(icon: Icons.task_alt_rounded, title: 'Queue is clear', message: 'No new orders waiting for confirmation.');
                }
                return Column(children: pending.map((o) => _orderTile(context, o)).toList());
              },
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _orderTile(BuildContext context, OrderModel o) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => showOrderDetailsDialog(context, o),
      leading: Icon(o.orderType == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 20, color: AppColors.textMuted),
      title: Row(children: [
        Expanded(child: Text('${o.customerName} · ${o.productName.split('(').first.trim()} ×${o.quantity}', style: AppTextStyles.bodyStrong)),
        StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
      ]),
      subtitle: Text('Placed ${AppFormatters.timeAgo(o.createdAt ?? DateTime.now())}', style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right_rounded, size: 18),
    );
  }
}

class GallonBadge extends StatelessWidget {
  const GallonBadge({super.key, required this.gallon});
  final GallonModel gallon;

  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: GallonStatus.color(gallon.status).withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
      child: Text(gallon.qrCodeValue, style: AppTextStyles.caption));
  }
}

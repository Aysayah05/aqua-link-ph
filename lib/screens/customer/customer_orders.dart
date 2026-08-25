import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/gallon_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/gallon_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';

class CustomerOrders extends StatelessWidget {
  const CustomerOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return StreamBuilder<List<OrderModel>>(
      stream: OrderService().streamOrders(userId: auth.profile?.uid),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final List<OrderModel> orders = snap.data!;

        if (orders.isEmpty) {
          return const EmptyState(
              icon: Icons.local_shipping_outlined,
              title: 'No orders yet',
              message: 'Order water from the home screen and track it here in real time.');
        }
        return ListView.separated(
          itemCount: orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) => _orderCard(context, orders[i]),
        );
      },
    );
  }

  Widget _orderCard(BuildContext context, OrderModel o) {
    final bool cancellable = o.status == OrderStatus.pending;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _detailSheet(context, o),
        child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(o.orderType == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 8),
            Expanded(child: Text('${o.productName} × ${o.quantity}', style: AppTextStyles.bodyStrong)),
            StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
          ]),
          const SizedBox(height: 10),
          _progressTrack(o.status),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: Text('Placed ${AppFormatters.timeAgo(o.createdAt ?? DateTime.now())}', style: AppTextStyles.caption)),
            Text(AppFormatters.peso(o.totalAmount), style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
            const SizedBox(width: 10),
            StatusChip(status: o.paymentStatus, label: PaymentStatus.label(o.paymentStatus), color: PaymentStatus.color(o.paymentStatus)),
          ]),
          if (o.driverNearby && o.status == OrderStatus.inTransit) ...[
            const SizedBox(height: 10),
            Container(padding: const EdgeInsets.all(10), decoration:
              BoxDecoration(color: AppColors.warning.withOpacity(0.1), border: Border.all(color: AppColors.warning.withOpacity(0.5)), borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.near_me_rounded, size: 17, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(child: Text('Your delivery is almost there!', style: AppTextStyles.bodyStrong)),
              ])),
          ],
          if (cancellable) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _cancel(context, o),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Cancel order'),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              ),
            ),
          ],
        ])),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, OrderModel o) async {
    final bool ok = await ConfirmDialog.show(context,
        title: 'Cancel this order?', message: 'Your pending order will be cancelled. This cannot be undone.', destructive: true);
    if (!ok || !context.mounted) return;
    try {
      await OrderService().cancelOrder(o.id);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cancel failed: $e'), backgroundColor: AppColors.danger));
    }
  }

  Widget _progressTrack(String status) {
    if (status == OrderStatus.cancelled) {
      return Text('This order was cancelled.', style: AppTextStyles.muted);
    }
    final int current = OrderStatus.stepIndex(status);
    return Row(children: List.generate(OrderStatus.activeFlow.length * 2 - 1, (idx) {
      if (idx.isOdd) {
        final int segment = idx ~/ 2;
        return Container(width: 14, height: 2.5, color: segment <= current && current > 0 ? AppColors.success : AppColors.border);
      }
      final int step = idx ~/ 2;
      final bool done = step < current;
      final bool active = step == current;
      final IconData icon = [Icons.schedule_rounded, Icons.check_rounded, Icons.water_rounded, Icons.local_shipping_rounded, Icons.home_rounded][step];
      final Color c = done || active ? (active ? AppColors.accent : AppColors.success) : AppColors.textMuted;
      return Tooltip(
        message: OrderStatus.label(OrderStatus.activeFlow[step]),
        child: Container(width: 27, height: 27,
          decoration: BoxDecoration(shape: BoxShape.circle, color: done || active ? c.withOpacity(0.16) : Colors.transparent, border: Border.all(color: active ? c : AppColors.border, width: active ? 2 : 1)),
          child: Icon(icon, size: 14, color: done || active ? c : AppColors.textMuted)),
      );
    }));
  }

  void _detailSheet(BuildContext context, OrderModel o) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
        child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Expanded(child: Text('Order details', style: AppTextStyles.h2)),
            IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
          ]),
          Card(color: AppColors.surfaceAlt, margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            InfoRow(label: 'Product', value: '${o.productName} × ${o.quantity}'),
            InfoRow(label: 'Unit price', value: AppFormatters.peso(o.unitPrice)),
            InfoRow(label: 'Delivery fee', value: AppFormatters.peso(AppConstants.deliveryFee)),
            InfoRow(label: 'Total', value: AppFormatters.peso(o.totalAmount)),
            InfoRow(label: 'Address', value: o.customerAddress),
            InfoRow(label: 'Contact', value: o.contactNumber.isEmpty ? o.customerPhone : o.contactNumber),
            InfoRow(label: 'Payment', value: '${PaymentStatus.label(o.paymentStatus)}${o.paymentMethod != null ? ' · ${PaymentMethod.label(o.paymentMethod!)}' : ''}'),
            InfoRow(label: 'Placed', value: AppFormatters.dateTime(o.createdAt ?? DateTime.now())),
          ]))),
          const SizedBox(height: 14),
          Text('Gallons on this order', style: AppTextStyles.h3),
          const SizedBox(height: 8),
          StreamBuilder<List<GallonModel>>(
            stream: GallonService().streamGallonsForOrder(o.id),
            builder: (ctx, gsnap) {
              final gallons = gsnap.data ?? [];
              if (gallons.isEmpty) {
                return Text('Gallon containers will appear here once staff prepares your order.', style: AppTextStyles.muted);
              }
              return Column(children: gallons.map((g) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.water_drop_rounded, size: 18, color: GallonStatus.color(g.status)),
                title: Text(g.qrCodeValue, style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
                subtitle: Text(_friendly(g.status), style: AppTextStyles.caption),
              )).toList());
            },
          ),
        ])),
      ),
    );
  }

  String _friendly(String gallonStatus) {
    switch (gallonStatus) {
      case GallonStatus.assigned:
        return 'Scheduled for your delivery';
      case GallonStatus.outForDelivery:
        return 'Currently being delivered to you';
      case GallonStatus.withCustomer:
        return 'With you — awaiting return';
      case GallonStatus.returned:
        return 'Returned to the station ✓';
    }
    return GallonStatus.label(gallonStatus);
  }
}

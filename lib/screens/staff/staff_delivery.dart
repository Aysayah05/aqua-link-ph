import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/order_model.dart';
import '../../services/gallon_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';
import '../shared/order_details_dialog.dart';

class StaffDelivery extends StatelessWidget {
  StaffDelivery({super.key});

  final OrderService _orders = OrderService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orders.streamOrders(status: OrderStatus.inTransit),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final List<OrderModel> transit =
            snap.data!.where((o) => o.orderType == OrderType.delivery).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Deliveries on the road', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Everything a driver needs per stop — no more scattered messages.', style: AppTextStyles.muted),
          const SizedBox(height: 12),
          Expanded(
            child: transit.isEmpty
                ? const EmptyState(icon: Icons.local_shipping_outlined, title: 'No active deliveries', message: 'Orders marked "Out for delivery" appear here.')
                : ListView.separated(
                    itemCount: transit.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _deliveryCard(context, transit[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _deliveryCard(BuildContext context, OrderModel o) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(o.customerName, style: AppTextStyles.h3)),
            StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              InfoRow(label: 'Address', value: o.customerAddress, icon: Icons.location_on_outlined),
              InfoRow(label: 'Contact', value: o.contactNumber.isEmpty ? o.customerPhone : o.contactNumber, icon: Icons.call_outlined),
              InfoRow(label: 'Order', value: '${o.productName} × ${o.quantity}', icon: Icons.water_drop_outlined),
              if (o.deliveryRequest.isNotEmpty)
                InfoRow(label: 'Request', value: o.deliveryRequest, icon: Icons.sticky_note_2_outlined),
            ])),
            const SizedBox(width: 8),
            Column(children: [
              IconButton.outlined(
                tooltip: 'Copy address',
                onPressed: () { Clipboard.setData(ClipboardData(text: '${o.customerAddress} — contact ${o.contactNumber}')); },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ]),
          ]),
          const SizedBox(height: 6),
          StreamBuilder<int>(
            stream: GallonService().streamGallonsForOrder(o.id).map((g) => g.length),
            builder: (context, gsnap) {
              return Text('${gsnap.data ?? 0} gallon(s) linked to this order', style: AppTextStyles.caption);
            },
          ),
          const Divider(),
          Wrap(spacing: 10, runSpacing: 10, children: [
            OutlinedButton.icon(
              onPressed: () async {
                await _orders.setDriverNearby(o.id, o.userId ?? '', true);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Near-arrival notification sent to the customer.')));
                }
              },
              icon: const Icon(Icons.near_me_rounded, size: 17),
              label: Text(o.driverNearby ? 'Notified ✓' : 'Notify near arrival'),
            ),
            FilledButton.icon(
              onPressed: () => showOrderDetailsDialog(context, o),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              icon: const Icon(Icons.check_circle_rounded, size: 17),
              label: const Text('Manage / complete'),
            ),
          ]),
        ]),
      ),
    );
  }
}

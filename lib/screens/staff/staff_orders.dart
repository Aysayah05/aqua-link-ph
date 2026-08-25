import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';
import '../shared/order_details_dialog.dart';

class StaffOrders extends StatefulWidget {
  const StaffOrders({super.key});

  @override
  State<StaffOrders> createState() => _StaffOrdersState();
}

class _StaffOrdersState extends State<StaffOrders> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: OrderService().streamOrders(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        List<OrderModel> orders = snap.data!
            .where((o) => o.status != OrderStatus.delivered && o.status != OrderStatus.cancelled)
            .toList();
        if (_filter.isNotEmpty) orders = orders.where((o) => o.status == _filter).toList();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(label: const Text('All open'), selected: _filter.isEmpty, onSelected: (_) => setState(() => _filter = '')),
            ...[OrderStatus.pending, OrderStatus.confirmed, OrderStatus.preparing, OrderStatus.inTransit].map((s) =>
                ChoiceChip(label: Text(OrderStatus.label(s)), selected: _filter == s, onSelected: (_) => setState(() => _filter = s))),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: orders.isEmpty
                ? const EmptyState(icon: Icons.task_alt_rounded, title: 'No open orders', message: 'New customer orders will appear here in real time.')
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) => _tile(context, orders[i]),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _tile(BuildContext context, OrderModel o) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      onTap: () => showOrderDetailsDialog(context, o),
      title: Row(children: [
        Icon(o.orderType == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 17, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(o.customerName, style: AppTextStyles.bodyStrong)),
        StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.productName} × ${o.quantity} · ${AppFormatters.peso(o.totalAmount)} · ${PaymentStatus.label(o.paymentStatus)}',
              style: AppTextStyles.muted),
          if (o.orderType == OrderType.delivery)
            Padding(padding: const EdgeInsets.only(top: 3), child: Text(o.customerAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.caption)),
        ]),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}

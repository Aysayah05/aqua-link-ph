import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../models/sale_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/order_service.dart';
import '../shared/order_details_dialog.dart';
import '../../widgets/common_widgets.dart';

class StaffTransactions extends StatefulWidget {
  const StaffTransactions({super.key});

  @override
  State<StaffTransactions> createState() => _StaffTransactionsState();
}

class _StaffTransactionsState extends State<StaffTransactions> {
  final OrderService _orders = OrderService();
  String? _verifyingId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: _orders.streamUnpaidOrders(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final List<OrderModel> unpaid = snap.data!;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Payment verification', style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text('Deliveries and in-transit orders still marked unpaid. Confirm the money was received to log an official sale.',
              style: AppTextStyles.muted),
          const SizedBox(height: 12),
          Expanded(
            child: unpaid.isEmpty
                ? const EmptyState(icon: Icons.fact_check_outlined, title: 'Nothing to verify', message: 'All payments are recorded. Great work!')
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: unpaid.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final OrderModel o = unpaid[i];
                        final bool busy = _verifyingId == o.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          onTap: () => showOrderDetailsDialog(context, o),
                          title: Row(children: [
                            Expanded(child: Text(o.customerName, style: AppTextStyles.bodyStrong)),
                            StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
                          ]),
                          subtitle: Text('${o.productName} × ${o.quantity} · ${AppFormatters.timeAgo(o.createdAt ?? DateTime.now())}',
                              style: AppTextStyles.muted),
                          trailing: busy
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                              : FilledButton.icon(
                                  onPressed: () => _verify(context, o),
                                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                  icon: const Icon(Icons.check_rounded, size: 17),
                                  label: const Text('Verify'),
                                ),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Future<void> _verify(BuildContext context, OrderModel o) async {
    String method = PaymentMethod.cash;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify payment received'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.customerName} — ${AppFormatters.peso(o.totalAmount)}', style: AppTextStyles.h3),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'Received via'),
            items: const [DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')), DropdownMenuItem(value: PaymentMethod.gcash, child: Text('GCash'))],
            onChanged: (v) => method = v ?? PaymentMethod.cash,
          ),
          const SizedBox(height: 6),
          Text('A sale record will be created automatically.', style: AppTextStyles.caption),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: AppColors.success), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    setState(() => _verifyingId = o.id);
    try {
      final String actor = context.read<AuthProvider>().profile?.name ?? 'Staff';
      await _orders.markPaid(
        orderId: o.id,
        paymentMethod: method,
        sale: SaleModel(
          id: '',
          amount: o.totalAmount,
          type: o.orderType,
          paymentMethod: method,
          recordedByName: actor,
          orderId: o.id,
          customerId: o.customerId,
          customerName: o.customerName,
          productSummary: '${o.productName} × ${o.quantity}',
        ),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment recorded for ${o.customerName}. Sales updated.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification failed: $e'), backgroundColor: AppColors.danger));
      }
    }
    if (mounted) setState(() => _verifyingId = null);
  }
}

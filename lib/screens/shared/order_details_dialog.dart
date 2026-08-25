import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/gallon_model.dart';
import '../../models/order_model.dart';
import '../../models/sale_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/gallon_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';

class OrderDetailsDialog extends StatefulWidget {
  const OrderDetailsDialog({super.key, required this.order, required this.actorName});
  final OrderModel order;
  final String actorName;

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  final OrderService _orders = OrderService();
  final GallonService _gallons = GallonService();
  bool _busy = false;

  OrderModel get o => widget.order;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$e'.replaceFirst('Exception: ', '')),
            backgroundColor: AppColors.danger));
        setState(() => _busy = false);
      }
    }
  }

  void _confirmStatus(String newStatus) {
    if (newStatus == OrderStatus.inTransit) {
      _run(() async {
        await _gallons.advanceOrderGallons(
            orderId: o.id,
            toStatus: GallonStatus.outForDelivery,
            byUserName: widget.actorName);
        await _orders.updateStatus(o.id, newStatus);
      });
      return;
    }
    if (newStatus == OrderStatus.delivered) {
      _promptDeliveryPayment();
      return;
    }
    if (newStatus == OrderStatus.cancelled) {
      _run(() async {
        await _gallons.releaseOrderGallons(orderId: o.id, byUserName: widget.actorName);
        await _orders.cancelOrder(o.id);
      });
      return;
    }
    _run(() => _orders.updateStatus(o.id, newStatus));
  }

  void _promptDeliveryPayment() {
    String method = PaymentMethod.cash;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete delivery'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Collect ${AppFormatters.peso(o.totalAmount)} from ${o.customerName}.',
              style: AppTextStyles.body),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'Payment received via'),
            items: const [
              DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')),
              DropdownMenuItem(value: PaymentMethod.gcash, child: Text('GCash')),
            ],
            onChanged: (v) => method = v ?? PaymentMethod.cash,
          ),
          const SizedBox(height: 6),
          Text('The sale record and gallon statuses update automatically.',
              style: AppTextStyles.caption),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => _completeDelivery(ctx, method),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Mark delivered'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeDelivery(BuildContext dialogCtx, String method) async {
    Navigator.pop(dialogCtx);
    await _run(() async {
      await _orders.markPaid(
        orderId: o.id,
        paymentMethod: method,
        sale: SaleModel(
          id: '',
          amount: o.totalAmount,
          type: o.orderType,
          paymentMethod: method,
          recordedByName: widget.actorName,
          orderId: o.id,
          customerId: o.customerId,
          customerName: o.customerName,
          productSummary: '${o.productName} × ${o.quantity}',
        ),
      );
      await _gallons.deliverOrderGallons(orderId: o.id);
      await _orders.updateStatus(o.id, OrderStatus.delivered);
    });
  }

  void _verifyPayment() {
    String method = o.paymentMethod ?? PaymentMethod.cash;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify payment'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Record ${AppFormatters.peso(o.totalAmount)} as paid.', style: AppTextStyles.body),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: method,
            decoration: const InputDecoration(labelText: 'Payment method'),
            items: const [
              DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')),
              DropdownMenuItem(value: PaymentMethod.gcash, child: Text('GCash')),
            ],
            onChanged: (v) => method = v ?? PaymentMethod.cash,
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _run(() async {
                await _orders.markPaid(
                  orderId: o.id,
                  paymentMethod: method,
                  sale: SaleModel(
                    id: '',
                    amount: o.totalAmount,
                    type: o.orderType,
                    paymentMethod: method,
                    recordedByName: widget.actorName,
                    orderId: o.id,
                    customerId: o.customerId,
                    customerName: o.customerName,
                    productSummary: '${o.productName} × ${o.quantity}',
                  ),
                );
              });
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            child: const Text('Confirm payment'),
          ),
        ],
      ),
    );
  }

  void _notifyNearby() {
    _run(() => _orders.setDriverNearby(o.id, o.userId ?? '', true));
  }

  Future<void> _autoAssignGallons() async {
    final qtyCtrl = TextEditingController(text: '${o.quantity}');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto-assign gallons'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Pick available gallon containers from station stock for ${o.customerName}.', style: AppTextStyles.muted),
          const SizedBox(height: 12),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many gallons?')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Assign')),
        ],
      ),
    );
    if (ok != true) return;
    final int qty = int.tryParse(qtyCtrl.text) ?? 0;
    await _run(() async {
      await GallonService().autoAssignGallons(
        count: qty,
        orderId: o.id,
        customerId: o.customerId,
        customerName: o.customerName,
        byUserName: widget.actorName,
      );
      Navigator.pop(context);
    });
  }

  List<Widget> _actions() {
    switch (o.status) {
      case OrderStatus.pending:
        return [
          OutlinedButton(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.cancelled),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel order')),
          FilledButton(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.confirmed),
              child: const Text('Confirm order')),
        ];
      case OrderStatus.confirmed:
        return [
          OutlinedButton(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.cancelled),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Cancel')),
          OutlinedButton.icon(
              onPressed: _busy ? null : _autoAssignGallons,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Assign gallons')),
          FilledButton.icon(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.preparing),
              icon: const Icon(Icons.water_rounded, size: 18),
              label: const Text('Start preparing')),
        ];
      case OrderStatus.preparing:
        return [
          FilledButton.icon(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.inTransit),
              icon: const Icon(Icons.local_shipping_rounded, size: 18),
              label: const Text('Out for delivery')),
        ];
      case OrderStatus.inTransit:
        return [
          if (!o.driverNearby && o.userId != null && o.userId!.isNotEmpty)
            OutlinedButton.icon(
                onPressed: _busy ? null : _notifyNearby,
                icon: const Icon(Icons.near_me_rounded, size: 18),
                label: const Text('Notify near arrival')),
          FilledButton.icon(
              onPressed: _busy ? null : () => _confirmStatus(OrderStatus.delivered),
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: const Text('Delivered')),
        ];
      case OrderStatus.delivered:
        if (o.paymentStatus == PaymentStatus.unpaid) {
          return [FilledButton.icon(onPressed: _busy ? null : _verifyPayment, icon: const Icon(Icons.fact_check_rounded, size: 18), label: const Text('Verify payment'))];
        }
        return [];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Expanded(child: Text('Order details', style: AppTextStyles.h2)),
              IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
            ]),
            Text('ID: ${o.id}', style: AppTextStyles.caption.copyWith(fontFamily: 'monospace')),
            const SizedBox(height: 16),

            Card(color: AppColors.surfaceAlt, margin: EdgeInsets.zero,
                child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(o.orderType == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 17, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(OrderType.label(o.orderType), style: AppTextStyles.caption),
                const Spacer(),
                StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
              ]),
              const SizedBox(height: 10),
              Text(o.customerName, style: AppTextStyles.h3),
              InfoRow(label: 'Contact', value: o.contactNumber.isEmpty ? o.customerPhone : o.contactNumber, icon: Icons.call_outlined),
              if (o.orderType == OrderType.delivery)
                InfoRow(label: 'Address', value: o.customerAddress, icon: Icons.location_on_outlined),
              InfoRow(label: 'Product', value: '${o.productName} × ${o.quantity}'),
              InfoRow(label: 'Unit price', value: AppFormatters.peso(o.unitPrice)),
              InfoRow(label: 'Total', value: AppFormatters.peso(o.totalAmount)),
              if (o.deliveryRequest.isNotEmpty)
                InfoRow(label: 'Request', value: o.deliveryRequest, icon: Icons.sticky_note_2_outlined),
              Row(children: [
                StatusChip(status: o.paymentStatus, label: PaymentStatus.label(o.paymentStatus), color: PaymentStatus.color(o.paymentStatus)),
                const SizedBox(width: 10),
                Text('Placed ${AppFormatters.timeAgo(o.createdAt ?? DateTime.now())}', style: AppTextStyles.caption),
              ]),
            ]))),
            const SizedBox(height: 16),

            if (o.driverNearby && o.status == OrderStatus.inTransit)
              Container(margin: const EdgeInsets.only(bottom: 14), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), border: Border.all(color: AppColors.accent.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Icon(Icons.near_me_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Near-arrival notification was sent to the customer.', style: AppTextStyles.muted)),
                ])),

            Text('Assigned gallons', style: AppTextStyles.h3),
            const SizedBox(height: 8),
            StreamBuilder<List<GallonModel>>(
              stream: _gallons.streamGallonsForOrder(o.id),
              builder: (context, snap) {
                final List<GallonModel> gallons = snap.data ?? [];
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator());
                }
                if (gallons.isEmpty) {
                  return Text('No gallons assigned yet. Assign them in the Gallons & QR module or scan each container.',
                      style: AppTextStyles.muted);
                }
                return Wrap(spacing: 8, runSpacing: 8, children: gallons.map((g) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () { Clipboard.setData(ClipboardData(text: g.qrCodeValue)); },
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(color: AppColors.surfaceAlt, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.qr_code_2_rounded, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(g.qrCodeValue, style: AppTextStyles.bodyStrong),
                        const SizedBox(width: 8),
                        Text(GallonStatus.label(g.status), style: AppTextStyles.caption),
                      ])),
                  );
                }).toList());
              },
            ),

            if (_actions().isNotEmpty) ...[
              const SizedBox(height: 22),
              Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: _actions()),
            ],
          ]),
        ),
      ),
    );
  }
}

Future<void> showOrderDetailsDialog(BuildContext context, OrderModel order) {
  final String actorName = Provider.of<AuthProvider>(context, listen: false).profile?.name ?? 'Staff';
  return showDialog<void>(
    context: context,
    builder: (_) => OrderDetailsDialog(order: order, actorName: actorName),
  );
}

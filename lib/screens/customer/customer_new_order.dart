import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_item_model.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';

class CustomerNewOrder extends StatefulWidget {
  const CustomerNewOrder({super.key});

  @override
  State<CustomerNewOrder> createState() => _CustomerNewOrderState();
}

class _CustomerNewOrderState extends State<CustomerNewOrder> {
  final OrderService _orders = OrderService();
  InventoryItemModel? _product;
  int _qty = 1;
  String _payment = PaymentMethod.cash;

  late final TextEditingController _addressCtrl;
  late final TextEditingController _contactCtrl;
  final TextEditingController _requestCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: context.read<AuthProvider>().profile?.address ?? '');
    _contactCtrl = TextEditingController(text: context.read<AuthProvider>().profile?.phone ?? '');
    InventoryService().streamItems().first.then((items) {
      if (mounted && items.isNotEmpty) {
        setState(() => _product = items.where((i) => i.category == 'Refill').isNotEmpty
            ? items.where((i) => i.category == 'Refill').first
            : items.first);
      }
    });
  }

  double get _subtotal => (_product?.unitPrice ?? 0) * _qty;
  double get _total => _subtotal + AppConstants.deliveryFee;

  Future<void> _submit(AuthProvider auth) async {
    if (_product == null) return;
    if (_addressCtrl.text.trim().isEmpty || _contactCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Add your delivery address and contact number.'),
          backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _submitting = true);
    try {
      final String orderId = await _orders.placeOrder(OrderModel(
        id: '',
        customerId: auth.profile!.uid,
        userId: auth.profile!.uid,
        customerName: auth.profile!.name,
        customerPhone: _contactCtrl.text.trim(),
        customerAddress: _addressCtrl.text.trim(),
        orderType: OrderType.delivery,
        productId: _product!.id,
        productName: _product!.name,
        unitPrice: _product!.unitPrice,
        quantity: _qty,
        totalAmount: _total,
        status: OrderStatus.pending,
        paymentStatus: PaymentStatus.unpaid,
        contactNumber: _contactCtrl.text.trim(),
        deliveryRequest: _requestCtrl.text.trim(),
      ));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.check_circle_rounded, color: AppColors.success, size: 44),
          title: const Text('Order placed!'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your order has been recorded and sent to ${AppConstants.stationName}.', style: AppTextStyles.body),
            const SizedBox(height: 12),
            InfoRow(label: 'Order ID', value: orderId),
            InfoRow(label: 'Product', value: '${_product!.name} × $_qty'),
            InfoRow(label: 'Total to pay', value: AppFormatters.peso(_total)),
            const SizedBox(height: 6),
            Text('Track its progress in My Orders. We will notify you when the driver is near.', style: AppTextStyles.muted),
          ]),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
          ],
        ),
      );
      setState(() {
        _qty = 1;
        _requestCtrl.clear();
        _submitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not place the order: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return StreamBuilder<List<InventoryItemModel>>(
      stream: InventoryService().streamItems(),
      builder: (context, snap) {
        final List<InventoryItemModel> products =
            (snap.data ?? []).where((i) => i.category == 'Refill' && i.quantityOnHand > 0).toList();

        return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Text('New delivery order', style: AppTextStyles.h1.copyWith(fontSize: 22)),
          const SizedBox(height: 2),
          Text('From ${AppConstants.stationName}', style: AppTextStyles.muted),
          const SizedBox(height: 16),

          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: '1 · Choose product'),
            const SizedBox(height: 10),
            if (!snap.hasData)
              const Center(child: CircularProgressIndicator())
            else if (products.isEmpty)
              Text('No products are available right now. Please check back later.', style: AppTextStyles.muted)
            else ...[
              DropdownButtonFormField<InventoryItemModel>(
                value: products.contains(_product) ? _product : products.first,
                decoration: const InputDecoration(labelText: 'Water type'),
                items: products.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} — ${AppFormatters.peso(p.unitPrice)}'))).toList(),
                onChanged: (v) => setState(() => _product = v),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Text('Gallons', style: AppTextStyles.bodyStrong),
                const Spacer(),
                IconButton.filledTonal(
                  onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                  icon: const Icon(Icons.remove_rounded, size: 19)),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('$_qty', style: AppTextStyles.h2)),
                IconButton.filledTonal(
                  onPressed: _qty < 20 ? () => setState(() => _qty++) : null,
                  icon: const Icon(Icons.add_rounded, size: 19)),
              ]),
            ],
          ]))),

          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: '2 · Delivery details'),
            const SizedBox(height: 10),
            TextField(controller: _addressCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Delivery address', hintText: 'House no., Street, Barangay')),
            const SizedBox(height: 12),
            TextField(controller: _contactCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contact number')),
            const SizedBox(height: 12),
            TextField(controller: _requestCtrl, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Delivery request (optional)', hintText: 'e.g., Call when you arrive at the gate')),
          ]))),

          const SizedBox(height: 14),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: '3 · Payment method'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: PaymentMethod.cash, label: Text('Cash on delivery'), icon: Icon(Icons.money_rounded, size: 17)),
                ButtonSegment(value: PaymentMethod.gcash, label: Text('GCash'), icon: Icon(Icons.phone_android_rounded, size: 17)),
              ],
              selected: {_payment},
              onSelectionChanged: (s) => setState(() => _payment = s.first),
            ),
            const Divider(height: 26),
            Row(children: [Expanded(child: Text('Subtotal', style: AppTextStyles.muted)), Text(AppFormatters.peso(_subtotal), style: AppTextStyles.bodyStrong)]),
            Row(children: [Expanded(child: Text('Delivery fee', style: AppTextStyles.muted)), Text(AppFormatters.peso(AppConstants.deliveryFee), style: AppTextStyles.bodyStrong)]),
            const SizedBox(height: 4),
            Row(children: [Expanded(child: Text('Total', style: AppTextStyles.h3)), Text(AppFormatters.peso(_total), style: AppTextStyles.statValue.copyWith(color: AppColors.accent))]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, height: 50,
                child: FilledButton.icon(
                  onPressed: (_submitting || products.isEmpty || !auth.isSignedIn) ? null : () => _submit(auth),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: _submitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 19),
                  label: Text(_submitting ? 'Submitting…' : 'Place order — ${AppFormatters.peso(_total)}'),
                )),
          ]))),
        ]);
      },
    );
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _contactCtrl.dispose();
    _requestCtrl.dispose();
    super.dispose();
  }
}

class CustomerNewOrderPage extends StatelessWidget {
  const CustomerNewOrderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Order water')), body: const CustomerNewOrder());
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_model.dart';
import '../../models/inventory_item_model.dart';
import '../../models/sale_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/customer_service.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import '../../widgets/common_widgets.dart';

enum SalesRange { today, week, month, all }

class AdminSales extends StatefulWidget {
  const AdminSales({super.key});

  @override
  State<AdminSales> createState() => _AdminSalesState();
}

class _AdminSalesState extends State<AdminSales> {
  final SalesService _service = SalesService();
  SalesRange _range = SalesRange.month;

  DateTime get _rangeStart {
    final DateTime now = DateTime.now();
    switch (_range) {
      case SalesRange.today:
        return now.dateOnly;
      case SalesRange.week:
        return now.dateOnly.subtract(const Duration(days: 6));
      case SalesRange.month:
        return DateTime(now.year, now.month);
      case SalesRange.all:
        return DateTime(2000);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: _service.streamSales(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final List<SaleModel> inRange =
            SalesService.inRange(snap.data!, _rangeStart, DateTime.now());
        final double total = SalesService.total(inRange);
        final int cashCount = inRange.where((s) => s.paymentMethod == PaymentMethod.cash).length;
        final int gcashCount = inRange.length - cashCount;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Wrap(spacing: 8, children: [
              for (final r in SalesRange.values)
                ChoiceChip(
                  label: Text(r == SalesRange.today ? 'Today' : r == SalesRange.week ? '7 days' : r == SalesRange.month ? 'This month' : 'All time'),
                  selected: _range == r,
                  onSelected: (_) => setState(() => _range = r),
                ),
            ]),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _walkInSaleDialog(context),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Record walk-in sale'),
            ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final int cols = c.maxWidth > 900 ? 4 : 2;
            return GridView.count(
              crossAxisCount: cols,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 132,
              children: [
                StatCard(label: 'Total sales', value: AppFormatters.peso(total), icon: Icons.payments_rounded, color: AppColors.success),
                StatCard(label: 'Transactions', value: '${inRange.length}', icon: Icons.receipt_rounded, color: AppColors.primary, subtitle: '${inRange.isEmpty ? 0 : (total / inRange.length).toStringAsFixed(0)} avg'),
                StatCard(label: 'Cash payments', value: '$cashCount', icon: Icons.money_rounded, color: AppColors.accent),
                StatCard(label: 'GCash payments', value: '$gcashCount', icon: Icons.phone_android_rounded, color: AppColors.purple),
              ],
            );
          }),
          const SizedBox(height: 14),
          Expanded(
            child: inRange.isEmpty
                ? const EmptyState(icon: Icons.receipt_outlined, title: 'No sales in this period')
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: inRange.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final SaleModel s = inRange[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                          leading: Icon(
                            s.type == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                            color: s.type == OrderType.delivery ? AppColors.accent : AppColors.primary,
                          ),
                          title: Text(s.customerName ?? 'Walk-in Customer', style: AppTextStyles.bodyStrong),
                          subtitle: Text('${s.productSummary.isNotEmpty ? s.productSummary : OrderType.label(s.type)} · ${PaymentMethod.label(s.paymentMethod)} · by ${s.recordedByName}', style: AppTextStyles.muted),
                          trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(AppFormatters.peso(s.amount), style: AppTextStyles.bodyStrong.copyWith(color: AppColors.success)),
                            Text(AppFormatters.dateTime(s.createdAt ?? DateTime.now()), style: AppTextStyles.caption),
                          ]),
                        );
                      },
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Future<void> _walkInSaleDialog(BuildContext context) async {
    final List<CustomerModel> customers = await CustomerService().fetchCustomersOnce();
    final List<InventoryItemModel> items = await InventoryService().streamItems().first;
    if (!context.mounted) return;

    InventoryItemModel? product = items.isEmpty ? null : items.first;
    CustomerModel? customer;
    String method = PaymentMethod.cash;
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Record walk-in sale'),
        content: SizedBox(width: 400,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<InventoryItemModel>(
              value: product,
              decoration: const InputDecoration(labelText: 'Product'),
              items: items.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} — ${AppFormatters.peso(p.unitPrice)}'))).toList(),
              onChanged: (v) => setD(() => product = v),
            ),
            const SizedBox(height: 10),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            const SizedBox(height: 10),
            DropdownButtonFormField<CustomerModel?>(
              value: customer,
              decoration: const InputDecoration(labelText: 'Customer (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Walk-in / anonymous')),
                ...customers.map((c) => DropdownMenuItem(value: c, child: Text(c.fullName))),
              ],
              onChanged: (v) => setD(() => customer = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [DropdownMenuItem(value: PaymentMethod.cash, child: Text('Cash')), DropdownMenuItem(value: PaymentMethod.gcash, child: Text('GCash'))],
              onChanged: (v) => setD(() => method = v ?? PaymentMethod.cash),
            ),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Note (optional)')),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Record sale')),
        ],
      )),
    );
    if (ok != true || !context.mounted || product == null) return;
    final int? qty = int.tryParse(qtyCtrl.text);
    if (qty == null || qty <= 0) {
      _toast(context, 'Enter a valid quantity.');
      return;
    }
    try {
      final String actor = context.read<AuthProvider>().profile?.name ?? 'Staff';
      await SalesService().recordSale(SaleModel(
        id: '',
        amount: product!.unitPrice * qty,
        type: OrderType.walkIn,
        paymentMethod: method,
        recordedByName: actor,
        customerId: customer?.id,
        customerName: customer?.fullName ?? 'Walk-in Customer',
        productSummary: '${product!.name} × $qty',
        note: noteCtrl.text.trim(),
      ));
      await InventoryService().adjustQuantity(product!.id, -qty);
    } catch (e) {
      _toast(context, 'Failed to record sale: $e');
    }
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
  }
}

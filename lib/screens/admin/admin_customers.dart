import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../services/customer_service.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';

class AdminCustomers extends StatefulWidget {
  const AdminCustomers({super.key});

  @override
  State<AdminCustomers> createState() => _AdminCustomersState();
}

class _AdminCustomersState extends State<AdminCustomers> {
  final CustomerService _service = CustomerService();
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CustomerModel>>(
      stream: _service.streamCustomers(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        List<CustomerModel> customers = snap.data!;
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          customers = customers
              .where((c) =>
                  c.fullName.toLowerCase().contains(q) ||
                  c.contactNumber.contains(q) ||
                  c.address.toLowerCase().contains(q))
              .toList();
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: SearchField(hint: 'Search name, number, or address…', onChanged: (v) => setState(() => _search = v))),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _addCustomerDialog,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: const Text('Add walk-in customer'),
            ),
          ]),
          const SizedBox(height: 14),
          Text('${customers.length} customer(s)', style: AppTextStyles.muted),
          const SizedBox(height: 8),
          Expanded(
            child: customers.isEmpty
                ? const EmptyState(icon: Icons.people_outline_rounded, title: 'No customers yet')
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: customers.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) => ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        leading: CircleAvatar(
                          radius: 19,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(customers[i].initials(), style: AppTextStyles.caption.copyWith(fontSize: 13)),
                        ),
                        title: Row(children: [
                          Expanded(child: Text(customers[i].fullName, style: AppTextStyles.bodyStrong)),
                          if (customers[i].hasAccount)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.accent.withOpacity(0.4))),
                              child: Text('Registered', style: AppTextStyles.caption.copyWith(color: AppColors.accent)),
                            ),
                        ]),
                        subtitle: Text('${customers[i].contactNumber} · ${customers[i].address}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.muted),
                        trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                        onTap: () => _profileDialog(customers[i]),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Future<void> _addCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addrCtrl = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add walk-in customer'),
        content: SizedBox(
          width: 380,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name'), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 10),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Contact number')),
            const SizedBox(height: 10),
            TextField(controller: addrCtrl, decoration: const InputDecoration(labelText: 'Address'), textCapitalization: TextCapitalization.words),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.addWalkInCustomer(fullName: nameCtrl.text, contactNumber: phoneCtrl.text.trim(), address: addrCtrl.text.trim());
    } catch (e) {
      _toast('Failed to add customer: $e');
    }
  }

  void _profileDialog(CustomerModel customer) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  CircleAvatar(radius: 24, backgroundColor: AppColors.primarySoft, child: Text(customer.initials(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(customer.fullName, style: AppTextStyles.h2),
                    Text(customer.hasAccount ? 'Registered account' : 'Walk-in record', style: AppTextStyles.caption),
                  ])),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 16),
                Card(color: AppColors.surfaceAlt, margin: EdgeInsets.zero, child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InfoRow(label: 'Contact', value: customer.contactNumber, icon: Icons.call_outlined),
                  InfoRow(label: 'Address', value: customer.address, icon: Icons.location_on_outlined),
                  if (customer.notes.isNotEmpty)
                    InfoRow(label: 'Notes', value: customer.notes, icon: Icons.sticky_note_2_outlined),
                ]))),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: StreamBuilder<List<OrderModel>>(
                    stream: OrderService().streamOrdersByCustomer(customer.id),
                    builder: (context, snap) {
                      final orders = snap.data ?? [];
                      return _miniStat('Total orders', '${orders.length}');
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: StreamBuilder<List<OrderModel>>(
                    stream: OrderService().streamOrdersByCustomer(customer.id),
                    builder: (context, snap) {
                      final double spent = (snap.data ?? [])
                          .where((o) => o.paymentStatus == PaymentStatus.paid)
                          .fold(0.0, (acc, o) => acc + o.totalAmount);
                      return _miniStat('Lifetime value', AppFormatters.peso(spent));
                    },
                  )),
                ]),
                const SizedBox(height: 16),
                Text('Order history', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                StreamBuilder<List<OrderModel>>(
                  stream: OrderService().streamOrdersByCustomer(customer.id),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    final orders = snap.data!.take(8).toList();
                    if (orders.isEmpty) {
                      return Text('No transactions recorded yet.', style: AppTextStyles.muted);
                    }
                    return Column(children: orders.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: Row(children: [
                        Icon(o.orderType == 'delivery' ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 9),
                        Expanded(child: Text('${o.productName.split('(').first.trim()} ×${o.quantity}', style: AppTextStyles.body)),
                        StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),                        const SizedBox(width: 10),
                        SizedBox(width: 70, child: Text(AppFormatters.peso(o.totalAmount), textAlign: TextAlign.right, style: AppTextStyles.bodyStrong)),
                      ]),
                    )).toList());
                  },
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surfaceAlt, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: AppTextStyles.caption),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.statValue.copyWith(fontSize: 17)),
      ]),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
  }
}

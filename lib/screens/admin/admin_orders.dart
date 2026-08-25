import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/order_model.dart';
import '../../services/order_service.dart';
import '../../widgets/common_widgets.dart';
import '../shared/order_details_dialog.dart';

class AdminOrders extends StatefulWidget {
  const AdminOrders({super.key});

  @override
  State<AdminOrders> createState() => _AdminOrdersState();
}

class _AdminOrdersState extends State<AdminOrders> {
  String _statusFilter = '';
  String _typeFilter = '';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<OrderModel>>(
      stream: OrderService().streamOrders(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        List<OrderModel> orders = snap.data!;
        if (_statusFilter.isNotEmpty) {
          orders = orders.where((o) => o.status == _statusFilter).toList();
        }
        if (_typeFilter.isNotEmpty) {
          orders = orders.where((o) => o.orderType == _typeFilter).toList();
        }
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          orders = orders
              .where((o) =>
                  o.customerName.toLowerCase().contains(q) ||
                  o.id.toLowerCase().contains(q))
              .toList();
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              flex: 2,
              child: SearchField(hint: 'Search by customer or order ID…', onChanged: (v) => setState(() => _search = v)),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: _filters()),
          ]),
          const SizedBox(height: 14),
          Text('${orders.length} order(s)', style: AppTextStyles.muted),
          const SizedBox(height: 8),
          Expanded(
            child: orders.isEmpty
                ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders found', message: 'Try changing the filters or search term.')
                : LayoutBuilder(builder: (context, c) {
                    final bool table = c.maxWidth > 760;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: table ? _table(orders) : ListView.separated(itemCount: orders.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) => _tile(orders[i])),
                    );
                  }),
          ),
        ]);
      },
    );
  }

  Widget _filters() {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      ChoiceChip(label: const Text('All'), selected: _statusFilter.isEmpty, onSelected: (_) => setState(() => _statusFilter = ''), labelStyle: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
      ...OrderStatus.all.map((s) => ChoiceChip(
            label: Text(OrderStatus.label(s)),
            selected: _statusFilter == s,
            onSelected: (_) => setState(() => _statusFilter = s == _statusFilter ? '' : s),
            labelStyle: AppTextStyles.caption,
          )),
      const VerticalDivider(width: 14),
      FilterChip(
        label: const Text('Delivery'),
        selected: _typeFilter == OrderType.delivery,
        onSelected: (_) => setState(() => _typeFilter = _typeFilter == OrderType.delivery ? '' : OrderType.delivery),
        labelStyle: AppTextStyles.caption,
      ),
      FilterChip(
        label: const Text('Walk-in'),
        selected: _typeFilter == OrderType.walkIn,
        onSelected: (_) => setState(() => _typeFilter = _typeFilter == OrderType.walkIn ? '' : OrderType.walkIn),
        labelStyle: AppTextStyles.caption,
      ),
    ]);
  }

  Widget _table(List<OrderModel> orders) {
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('CUSTOMER')),
            DataColumn(label: Text('TYPE')),
            DataColumn(label: Text('ITEMS')),
            DataColumn(label: Text('TOTAL'), numeric: true),
            DataColumn(label: Text('STATUS')),
            DataColumn(label: Text('PAYMENT')),
            DataColumn(label: Text('PLACED')),
            DataColumn(label: Text('')),
          ],
          rows: orders.map((OrderModel o) {
            return DataRow(onSelectChanged: (_) => showOrderDetailsDialog(context, o), cells: [
              DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.customerName, style: AppTextStyles.bodyStrong),
                Text(o.contactNumber.isEmpty ? o.customerPhone : o.contactNumber, style: AppTextStyles.caption),
              ])),
              DataCell(Text(OrderType.label(o.orderType))),
              DataCell(Text('${o.productName.split('(').first.trim()} × ${o.quantity}')),
              DataCell(Text(AppFormatters.peso(o.totalAmount), style: AppTextStyles.bodyStrong)),
              DataCell(StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status))),
              DataCell(StatusChip(status: o.paymentStatus, label: PaymentStatus.label(o.paymentStatus), color: PaymentStatus.color(o.paymentStatus))),
              DataCell(Text(AppFormatters.timeAgo(o.createdAt ?? DateTime.now()), style: AppTextStyles.muted)),
              const DataCell(Icon(Icons.chevron_right_rounded, size: 18)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _tile(OrderModel o) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      onTap: () => showOrderDetailsDialog(context, o),
      title: Row(children: [
        Expanded(child: Text(o.customerName, style: AppTextStyles.bodyStrong)),
        StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${o.productName} × ${o.quantity} · ${OrderType.label(o.orderType)}', style: AppTextStyles.muted),
          const SizedBox(height: 4),
          Row(children: [
            Text(AppFormatters.peso(o.totalAmount), style: AppTextStyles.bodyStrong),
            const SizedBox(width: 10),
            Icon(Icons.circle, size: 5, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Text(PaymentStatus.label(o.paymentStatus), style: AppTextStyles.caption),
          ]),
        ]),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
    );
  }
}

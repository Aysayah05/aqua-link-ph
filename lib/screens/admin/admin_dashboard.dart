import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/expense_model.dart';
import '../../models/gallon_model.dart';
import '../../models/inventory_item_model.dart';
import '../../models/order_model.dart';
import '../../models/sale_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/expense_service.dart';
import '../../services/inventory_service.dart';
import '../../services/order_service.dart';
import '../../services/sales_service.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';
import '../shared/order_details_dialog.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    return ListView(
      children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Good day, ${_firstName(auth.profile?.name)}',
                  style: AppTextStyles.h1.copyWith(fontSize: 22)),
              const SizedBox(height: 2),
              Text('${AppConstants.stationName} · ${AppFormatters.date(DateTime.now())}',
                  style: AppTextStyles.muted),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        _buildStatRow(),
        const SizedBox(height: 18),
        _buildFinancialSummary(),
        const SizedBox(height: 18),
        _buildCharts(context),
        const SizedBox(height: 18),
        _buildRecentOrdersAndAlerts(context),
      ],
    );
  }

  String _firstName(String? name) => (name ?? '').split(' ').first;

  Widget _buildStatRow() {
    return LayoutBuilder(builder: (context, c) {
      final int cols = c.maxWidth > 1100 ? 4 : (c.maxWidth > 640 ? 2 : 1);
      return StreamBuilder<List<SaleModel>>(
          stream: SalesService().streamSales(),
          builder: (context, salesSnap) {
            return StreamBuilder<List<OrderModel>>(
                stream: OrderService().streamOrders(),
                builder: (context, ordersSnap) {
                  return StreamBuilder<List<GallonModel>>(
                      stream: GallonCountSource().stream(),
                      builder: (context, gallonsSnap) {
                        return StreamBuilder<List<InventoryItemModel>>(
                            stream: InventoryService().streamItems(),
                            builder: (context, invSnap) {
                              final List<SaleModel> sales = salesSnap.data ?? [];
                              final List<OrderModel> orders = (ordersSnap.data ?? [])
                                  .where((o) =>
                                      o.status != OrderStatus.cancelled &&
                                      o.status != OrderStatus.delivered)
                                  .toList();
                              final List<GallonModel> gallons = gallonsSnap.data ?? [];
                              final int withCustomer = gallons
                                  .where((g) => g.status == GallonStatus.withCustomer)
                                  .length;
                              final int lowStock =
                                  (invSnap.data ?? []).where((i) => i.isLowStock).length;
                              final double today =
                                  SalesService.totalForDay(sales, DateTime.now());

                              return _wrapGrid(cols, [
                                StatCard(label: "Today's Sales", value: AppFormatters.peso(today), icon: Icons.point_of_sale_rounded, color: AppColors.success),
                                StatCard(label: 'Active Orders', value: '${orders.length}', icon: Icons.local_shipping_rounded, color: AppColors.accent, subtitle: '${orders.where((o) => o.status == OrderStatus.pending).length} pending'),
                                StatCard(label: 'Gallons With Customers', value: '$withCustomer', icon: Icons.water_drop_rounded, color: AppColors.primary, subtitle: '${gallons.length} registered total'),
                                StatCard(label: 'Low Stock Items', value: '$lowStock', icon: Icons.warning_amber_rounded, color: lowStock > 0 ? AppColors.warning : AppColors.textMuted, subtitle: lowStock > 0 ? 'Needs restocking' : 'All good'),
                              ]);
                            });
                      });
                });
          });
    });
  }

  Widget _buildFinancialSummary() {
    final DateTime now = DateTime.now();
    final DateTime monthStart = DateTime(now.year, now.month);
    return LayoutBuilder(builder: (context, c) {
      final int cols = c.maxWidth > 1100 ? 3 : 1;
      return StreamBuilder<List<SaleModel>>(
          stream: SalesService().streamSales(),
          builder: (context, salesSnap) {
            return StreamBuilder<List<ExpenseModel>>(
                stream: ExpenseService().streamExpenses(),
                builder: (context, expSnap) {
                  final double revenue = SalesService.inRange(
                          salesSnap.data ?? [], monthStart, now)
                      .fold(0.0, (s, x) => s + x.amount);
                  final double expenses =
                      ExpenseService.totalInMonth(expSnap.data ?? [], now);
                  final double profit = revenue - expenses;
                  return _wrapGrid(
                      cols,
                      [
                        StatCard(label: 'Revenue · ${AppFormatters.monthYear(now)}', value: AppFormatters.peso(revenue), icon: Icons.trending_up_rounded, color: AppColors.primary),
                        StatCard(label: 'Expenses · This Month', value: AppFormatters.peso(expenses), icon: Icons.payments_rounded, color: AppColors.danger),
                        StatCard(label: 'Profit · This Month', value: AppFormatters.peso(profit), icon: Icons.account_balance_wallet_rounded, color: profit >= 0 ? AppColors.success : AppColors.danger, subtitle: 'Revenue − Expenses'),
                      ]);
                });
          });
    });
  }

  Widget _buildCharts(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final bool sideBySide = c.maxWidth > 1000;
      final Widget salesChartCard = Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Daily Sales · Last 14 Days', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            SizedBox(height: 210,
                child: StreamBuilder<List<SaleModel>>(
                    stream: SalesService().streamSales(),
                    builder: (context, snap) {
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final LinkedHashMap<DateTime, double> byDay =
                          LinkedHashMap.from(SalesService.byDay(snap.data!, 14));
                      return SalesBarChart(data: Map<DateTime, double>.from(byDay));
                    })),
          ]),
        ),
      );
      final Widget expenseChartCard = Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Expense Breakdown · This Month', style: AppTextStyles.h3),
            const SizedBox(height: 16),
            StreamBuilder<List<ExpenseModel>>(
                stream: ExpenseService().streamExpenses(),
                builder: (context, snap) {
                  if (!snap.hasData) return const SizedBox(height: 180, child: Center(child: CircularProgressIndicator()));
                  final DateTime now = DateTime.now();
                  final Map<String, double> byCat = ExpenseService.byCategory(
                      (snap.data!).where((e) =>
                          e.spentAt.year == now.year && e.spentAt.month == now.month).toList());
                  if (byCat.isEmpty) {
                    return const EmptyState(icon: Icons.pie_chart_outline_rounded, title: 'No expenses yet this month');
                  }
                  return ExpensePieChart(data: byCat);
                }),
          ]),
        ),
      );
      if (!sideBySide) {
        return Column(children: [salesChartCard, const SizedBox(height: 16), expenseChartCard]);
      }
      return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(flex: 3, child: salesChartCard),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: expenseChartCard),
        ]),
      );
    });
  }

  Widget _buildRecentOrdersAndAlerts(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final bool sideBySide = c.maxWidth > 1000;
      final Widget recent = Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionHeader(title: 'Recent Orders', trailing: TextButton(onPressed: () {}, child: const Text('View all'))),
            const SizedBox(height: 8),
            StreamBuilder<List<OrderModel>>(
              stream: OrderService().streamOrders(),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                final List<OrderModel> orders = snap.data!.take(7).toList();
                if (orders.isEmpty) {
                  return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders yet');
                }
                return Column(children: [
                  ...orders.map((o) => InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => showOrderDetailsDialog(context, o),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          child: Row(children: [
                            Icon(o.orderType == OrderType.delivery ? Icons.local_shipping_outlined : Icons.storefront_outlined, size: 18, color: AppColors.textMuted),
                            const SizedBox(width: 10),
                            Expanded(child: Text(o.customerName, style: AppTextStyles.bodyStrong)),
                            Text(AppFormatters.timeAgo(o.createdAt ?? DateTime.now()), style: AppTextStyles.caption),
                            const SizedBox(width: 12),
                            StatusChip(status: o.status, label: OrderStatus.label(o.status), color: OrderStatus.color(o.status)),
                            const SizedBox(width: 12),
                            SizedBox(width: 84,
                                child: Text(AppFormatters.peso(o.totalAmount), textAlign: TextAlign.right, style: AppTextStyles.bodyStrong)),
                          ]),
                        ),
                      )),
                ]);
              },
            ),
          ]),
        ),
      );
      if (!sideBySide) return recent;
      return recent;
    });
  }

  Widget _wrapGrid(int cols, List<Widget> cards) {
    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: cols == 1 ? 3.4 : 1.75,
      children: cards,
    );
  }
}

class GallonCountSource {
  Query<Map<String, dynamic>> query() =>
      FirebaseFirestore.instance.collection(Collections.gallons) as Query<Map<String, dynamic>>;

  Stream<List<GallonModel>> stream() => query()
      .snapshots()
      .map((snap) => snap.docs.map(GallonModel.fromDoc).toList());
}

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/expense_model.dart';
import '../../models/sale_model.dart';
import '../../services/expense_service.dart';
import '../../services/sales_service.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';

class AdminReports extends StatefulWidget {
  const AdminReports({super.key});

  @override
  State<AdminReports> createState() => _AdminReportsState();
}

class _AdminReportsState extends State<AdminReports> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SaleModel>>(
      stream: SalesService().streamSales(),
      builder: (context, salesSnap) {
        return StreamBuilder<List<ExpenseModel>>(
          stream: ExpenseService().streamExpenses(),
          builder: (context, expSnap) {
            if (!salesSnap.hasData || !expSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final List<SaleModel> sales = salesSnap.data!;
            final List<ExpenseModel> expenses = expSnap.data!;
            final DateTime now = DateTime.now();

            final double revenueToday = SalesService.totalForDay(sales, now);
            final DateTime monthStart = DateTime(now.year, now.month);
            final double revenueMonth =
                SalesService.inRange(sales, monthStart, now).fold(0.0, (s, x) => s + x.amount);
            final double expensesMonth = ExpenseService.totalInMonth(expenses, now);
            final double profitMonth = revenueMonth - expensesMonth;

            final Map<String, double> revByMonth = SalesService.byMonth(sales, 6);
            final Map<String, double> expSeries = {
              for (final String key in revByMonth.keys) key: 0
            };
            for (final ExpenseModel e in expenses) {
              final String key =
                  '${e.spentAt.year}-${e.spentAt.month.toString().padLeft(2, '0')}';
              if (expSeries.containsKey(key)) expSeries[key] = expSeries[key]! + e.amount;
            }

            return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
              LayoutBuilder(builder: (context, c) {
                final int cols = c.maxWidth > 950 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: cols,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 132,
                  children: [
                    StatCard(label: "Today's revenue", value: AppFormatters.peso(revenueToday), icon: Icons.today_rounded, color: AppColors.accent),
                    StatCard(label: 'Revenue this month', value: AppFormatters.peso(revenueMonth), icon: Icons.trending_up_rounded, color: AppColors.primary),
                    StatCard(
                        label: 'Profit this month',
                        value: AppFormatters.peso(profitMonth),
                        icon: Icons.savings_rounded,
                        color: profitMonth >= 0 ? AppColors.success : AppColors.danger,
                        subtitle: 'Revenue − ${AppFormatters.peso(expensesMonth)} expenses'),
                  ],
                );
              }),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Revenue vs Expenses · Last 6 Months', style: AppTextStyles.h3),
                    Text('Profit is computed as recorded revenue minus recorded expenses.', style: AppTextStyles.muted),
                    const SizedBox(height: 16),
                    RevenueExpenseLineChart(
                        revenueSeries: revByMonth,
                        expenseSeries: expSeries,
                        labels: revByMonth.keys.toList()),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Daily Sales · Last 30 Days', style: AppTextStyles.h3),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 220,
                      child: SalesBarChart(data: SalesService.byDay(sales, 30)),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Weekly Summary · Last 6 Weeks', style: AppTextStyles.h3),
                    const SizedBox(height: 12),
                    _weeklyTable(sales, expenses),
                  ]),
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  Widget _weeklyTable(List<SaleModel> sales, List<ExpenseModel> expenses) {
    final DateTime now = DateTime.now();
    final List<DataRow> rows = [];
    for (int w = 0; w < 6; w++) {
      final DateTime end = now.dateOnly.subtract(Duration(days: 7 * w));
      final DateTime start = end.subtract(const Duration(days: 6));
      final double rev = SalesService.inRange(sales, start, end).fold(0.0, (s, x) => s + x.amount);
      final double exp = ExpenseService.totalInRange(expenses, start, end);
      rows.add(DataRow(cells: [
        DataCell(Text('W${6 - w} (${start.month}/${start.day}–${end.month}/${end.day})')),
        DataCell(Text(AppFormatters.peso(rev))),
        DataCell(Text(AppFormatters.peso(exp))),
        DataCell(Text(AppFormatters.peso(rev - exp), style: TextStyle(color: rev - exp >= 0 ? AppColors.success : AppColors.danger))),
      ]));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('WEEK')),
          DataColumn(label: Text('REVENUE'), numeric: true),
          DataColumn(label: Text('EXPENSES'), numeric: true),
          DataColumn(label: Text('PROFIT'), numeric: true),
        ],
        rows: rows,
      ),
    );
  }
}

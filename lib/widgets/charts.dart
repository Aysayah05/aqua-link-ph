import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/formatters.dart';

class SalesBarChart extends StatelessWidget {
  const SalesBarChart({super.key, required this.data});
  final Map<DateTime, double> data;

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<DateTime, double>> entries = data.entries.toList();
    final double maxY = entries.map((e) => e.value).fold(0.0, max2) * 1.25;
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 100 : maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _interval(maxY),
          getDrawingHorizontalLine: (v) =>
              const FlLine(color: AppColors.border, strokeWidth: 0.6),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: _interval(maxY),
              getTitlesWidget: (v, _) => Text(_compact(v), style: AppTextStyles.caption),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (v, _) {
                final int i = v.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                final DateTime d = entries[i].key;
                if (entries.length > 10 && i % 3 != 0 && i != entries.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(AppFormatters.shortDate(d), style: AppTextStyles.caption));
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
              AppFormatters.peso(rod.toY),
              AppTextStyles.bodyStrong.copyWith(color: Colors.white),
            ),
          ),
        ),
        barGroups: List.generate(entries.length, (i) {
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: entries[i].value,
              width: 14,
              color: entries[i].key == DateTime.now().dateOnly
                  ? AppColors.accent
                  : AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ]);
        }),
      ),
    );
  }

  static double max2(double a, double b) => a > b ? a : b;

  double _interval(double maxY) {
    if (maxY <= 0) return 25;
    final double rough = maxY / 4;
    final double pow = rough.abs() < 1 ? 1 : 1;
    double interval = pow;
    while (interval < rough) interval *= 2;
    return interval;
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    return v.toInt().toString();
  }
}

class ExpensePieChart extends StatelessWidget {
  const ExpensePieChart({super.key, required this.data});
  final Map<String, double> data;

  static const List<Color> palette = [
    Color(0xFF2F80ED),
    Color(0xFF27C6DA),
    Color(0xFF9B51E0),
    Color(0xFFF2994A),
    Color(0xFFEB5757),
    Color(0xFF2ECC71),
    Color(0xFFF2C94C),
    Color(0xFF8CA0BF),
  ];

  @override
  Widget build(BuildContext context) {
    final List<MapEntry<String, double>> entries = data.entries.toList();
    final double total = entries.fold(0.0, (s, e) => s + e.value);
    return Column(children: [
      SizedBox(
        height: 180,
        child: PieChart(PieChartData(
          centerSpaceRadius: 42,
          sectionsSpace: 3,
          sections: List.generate(entries.length, (i) {
            final double pct = total > 0 ? entries[i].value / total * 100 : 0;
            return PieChartSectionData(
              value: entries[i].value,
              color: palette[i % palette.length],
              radius: 46,
              title: pct >= 12 ? '${pct.toStringAsFixed(0)}%' : '',
              titleStyle: AppTextStyles.caption.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11),
            );
          }),
        )),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 14,
        runSpacing: 8,
        children: List.generate(entries.length, (i) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text('${entries[i].key} · ${AppFormatters.peso(entries[i].value)}',
                style: AppTextStyles.caption),
          ]);
        }),
      ),
    ]);
  }
}

class RevenueExpenseLineChart extends StatelessWidget {
  const RevenueExpenseLineChart({
    super.key,
    required this.revenueSeries,
    required this.expenseSeries,
    required this.labels,
  });

  final Map<String, double> revenueSeries;
  final Map<String, double> expenseSeries;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final double maxV = <double>[
      ...revenueSeries.values,
      ...expenseSeries.values,
      1
    ].reduce((a, b) => a > b ? a : b) * 1.2;

    LineChartBarData series(Map<String, double> values, Color color) => LineChartBarData(
          spots: List.generate(labels.length, (i) {
            final String key = labels[i];
            return FlSpot(i.toDouble(), values[key] ?? 0);
          }),
          isCurved: true,
          color: color,
          barWidth: 3,
          dotData: const FlDotData(show: true),
          belowBarData: BarAreaData(show: true, color: color.withOpacity(0.12)),
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        _legend(AppColors.primary, 'Revenue'),
        const SizedBox(width: 18),
        _legend(AppColors.danger, 'Expenses'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 220,
        child: LineChart(LineChartData(
          minY: 0,
          maxY: maxV,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxV / 5,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.6),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 48,
                  getTitlesWidget: (v, _) => Text(_compact(v), style: AppTextStyles.caption)),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 26,
                  getTitlesWidget: (v, _) {
                final int i = v.toInt();
                if (i < 0 || i >= labels.length) return const SizedBox.shrink();
                return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text(_monthLabel(labels[i]), style: AppTextStyles.caption));
              }),
            ),
          ),
          lineBarsData: [series(revenueSeries, AppColors.primary), series(expenseSeries, AppColors.danger)],
        )),
      ),
    ]);
  }

  Widget _legend(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 16, height: 4, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: AppTextStyles.caption),
      ]);

  String _monthLabel(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return key;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final int m = int.tryParse(parts[1]) ?? 1;
    return months[m - 1];
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toInt().toString();
  }
}

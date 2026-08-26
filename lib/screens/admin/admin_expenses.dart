import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/expense_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/expense_service.dart';
import '../../widgets/charts.dart';
import '../../widgets/common_widgets.dart';

class AdminExpenses extends StatefulWidget {
  const AdminExpenses({super.key});

  @override
  State<AdminExpenses> createState() => _AdminExpensesState();
}

class _AdminExpensesState extends State<AdminExpenses> {
  final ExpenseService _service = ExpenseService();
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExpenseModel>>(
      stream: _service.streamExpenses(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        List<ExpenseModel> expenses = snap.data!;
        if (_categoryFilter != null) {
          expenses = expenses.where((e) => e.category == _categoryFilter).toList();
        }
        final DateTime now = DateTime.now();
        final double thisMonth = ExpenseService.totalInMonth(snap.data!, now);
        final Map<String, double> byCat =
            ExpenseService.byCategory(snap.data!.where((e) => e.spentAt.year == now.year && e.spentAt.month == now.month).toList());

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Wrap(spacing: 6, runSpacing: 6, children: [
              ChoiceChip(label: const Text('All categories'), selected: _categoryFilter == null, onSelected: (_) => setState(() => _categoryFilter = null)),
              ...ExpenseCategories.all.map((c) => ChoiceChip(label: Text(c), selected: _categoryFilter == c, onSelected: (_) => setState(() => _categoryFilter = c == _categoryFilter ? null : c))),
            ])),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _expenseDialog(context, null),
              icon: const Icon(Icons.add_card_rounded, size: 18),
              label: const Text('Record expense'),
            ),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, c) {
            final bool sideBySide = c.maxWidth > 900;
            final Widget totalCard = StatCard(
                label: 'Total · ${AppFormatters.monthYear(now)}',
                value: AppFormatters.peso(thisMonth),
                icon: Icons.payments_rounded,
                color: AppColors.danger);
            final Widget pieCard = Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: byCat.isEmpty
                    ? const SizedBox(
                        height: 170,
                        child: Center(child: Text('No expenses recorded this month', style: AppTextStyles.muted)))
                    : ExpensePieChart(data: byCat),
              ),
            );
            if (sideBySide) {
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 280, child: totalCard),
                    const SizedBox(width: 12),
                    Expanded(child: pieCard),
                  ],
                ),
              );
            }
            return Column(children: [
              totalCard,
              const SizedBox(height: 12),
              pieCard,
            ]);
          }),
          const SizedBox(height: 12),
          Expanded(
            child: expenses.isEmpty
                ? const EmptyState(icon: Icons.payments_outlined, title: 'No expenses recorded')
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final ExpenseModel e = expenses[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                          leading: Icon(Icons.money_off_csred_rounded, color: AppColors.danger.withOpacity(0.85), size: 21),
                          title: Text(e.title, style: AppTextStyles.bodyStrong),
                          subtitle: Text('${e.category} · recorded by ${e.createdByName}', style: AppTextStyles.muted),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text('−${AppFormatters.peso(e.amount)}', style: AppTextStyles.bodyStrong.copyWith(color: AppColors.danger)),
                            IconButton(icon: const Icon(Icons.edit_outlined, size: 17), onPressed: () => _expenseDialog(context, e)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 17), onPressed: () => _delete(context, e)),
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

  Future<void> _expenseDialog(BuildContext context, ExpenseModel? existing) async {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    String category = existing?.category ?? ExpenseCategories.all.first;
    DateTime spentAt = existing?.spentAt ?? DateTime.now();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null ? 'Record expense' : 'Edit expense'),
        content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title'), textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: ExpenseCategories.all.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setD(() => category = v ?? category),
          ),
          const SizedBox(height: 10),
          TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₱)')),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_month_rounded, size: 20),
            title: Text(AppFormatters.date(spentAt), style: AppTextStyles.body),
            onTap: () async {
              final picked = await showDatePicker(context: ctx, initialDate: spentAt, firstDate: DateTime(2020), lastDate: DateTime.now());
              if (picked != null) setD(() => spentAt = picked);
            },
          ),
          TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes (optional)'), maxLines: 2),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing == null ? 'Record' : 'Save')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final double? amount = double.tryParse(amountCtrl.text.replaceAll(',', ''));
    if (titleCtrl.text.trim().isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid title and amount.'), backgroundColor: AppColors.danger));
      return;
    }
    try {
      final String actor = context.read<AuthProvider>().profile?.name ?? 'Admin';
      final ExpenseModel model = ExpenseModel(
        id: '',
        title: titleCtrl.text.trim(),
        category: category,
        amount: amount,
        spentAt: spentAt,
        createdByName: actor,
        notes: notesCtrl.text.trim(),
      );
      if (existing == null) {
        await _service.addExpense(model);
      } else {
        await _service.updateExpense(existing.id, model);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e'), backgroundColor: AppColors.danger));
    }
  }

  Future<void> _delete(BuildContext context, ExpenseModel e) async {
    final bool ok = await ConfirmDialog.show(context, title: 'Delete expense', message: 'Delete "${e.title}"?', destructive: true, confirmLabel: 'Delete');
    if (!ok || !context.mounted) return;
    await _service.deleteExpense(e.id);
  }
}

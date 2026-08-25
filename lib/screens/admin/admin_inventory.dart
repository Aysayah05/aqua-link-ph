import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/inventory_item_model.dart';
import '../../services/inventory_service.dart';
import '../../widgets/common_widgets.dart';

class AdminInventory extends StatelessWidget {
  AdminInventory({super.key});

  final InventoryService _service = InventoryService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<InventoryItemModel>>(
      stream: _service.streamItems(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final List<InventoryItemModel> items = snap.data!;
        final int lowCount = items.where((i) => i.isLowStock).length;

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(
                  'Stock monitoring for supplies and refill volume. Individually QR-tracked gallons are managed separately in Gallons & QR.',
                  style: AppTextStyles.muted),
            ),
            FilledButton.icon(
              onPressed: () => _itemDialog(context, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add item'),
            ),
          ]),
          const SizedBox(height: 12),
          if (lowCount > 0)
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.09),
                border: Border.all(color: AppColors.warning.withOpacity(0.45)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Reorder alert: $lowCount item(s) at or below their reorder level.', style: AppTextStyles.bodyStrong)),
              ]),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: items.isEmpty
                ? EmptyState(icon: Icons.inventory_2_outlined, title: 'No inventory items', message: 'Add products and supplies you want to monitor.', actionLabel: 'Add item', onAction: () => _itemDialog(context, null))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.7),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _tile(context, items[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _tile(BuildContext context, InventoryItemModel item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _adjustDialog(context, item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.category.toUpperCase(), style: AppTextStyles.caption),
                  const SizedBox(height: 3),
                  Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.h3),
                ]),
              ),
              PopupMenuButton<String>(
                tooltip: 'Options',
                icon: const Icon(Icons.more_vert_rounded, size: 19),
                onSelected: (v) {
                  if (v == 'edit') _itemDialog(context, item);
                  if (v == 'delete') _deleteItem(context, item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit item')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ]),
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${item.quantityOnHand}', style: AppTextStyles.statValue.copyWith(color: item.isLowStock ? AppColors.warning : AppColors.textPrimary)),
                const SizedBox(width: 2),
                Text(item.unitLabel, style: AppTextStyles.muted),
                const SizedBox(height: 3),
                Text('reorder at ${item.reorderLevel}', style: AppTextStyles.caption),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(AppFormatters.peso(item.unitPrice), style: AppTextStyles.bodyStrong.copyWith(fontSize: 15)),
                Text('per ${item.unitLabel.replaceAll(RegExp(r's$'), '')}', style: AppTextStyles.caption),
              ]),
            ]),
            if (item.isLowStock)
              Container(margin: const EdgeInsets.only(top: 8), padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.14), borderRadius: BorderRadius.circular(6)),
                child: Text('LOW STOCK', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w800))),
          ]),
        ),
      ),
    );
  }

  Future<void> _adjustDialog(BuildContext context, InventoryItemModel item) async {
    final deltaCtrl = TextEditingController(text: '10');
    bool increase = true;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text('Adjust stock — ${item.name}'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Add')), ButtonSegment(value: false, label: Text('Remove'))],
            selected: {increase},
            onSelectionChanged: (s) => setD(() => increase = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: deltaCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantity (${item.unitLabel})')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final int? delta = int.tryParse(deltaCtrl.text);
    if (delta == null || delta <= 0) return;
    try {
      await _service.adjustQuantity(item.id, increase ? delta : -delta);
    } catch (e) {
      _toast(context, 'Adjustment failed: $e');
    }
  }

  Future<void> _itemDialog(BuildContext context, InventoryItemModel? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: existing != null ? existing.unitPrice.toString() : '');
    final qtyCtrl = TextEditingController(text: existing?.quantityOnHand.toString() ?? '');
    final reorderCtrl = TextEditingController(text: existing?.reorderLevel.toString() ?? '15');
    String category = existing?.category ?? 'Refill';
    String unit = existing?.unitLabel ?? 'gallons';

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: Text(existing == null ? 'Add inventory item' : 'Edit item'),
        content: SizedBox(width: 380,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name'), textCapitalization: TextCapitalization.words),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: const ['Refill', 'Containers', 'Supplies', 'Others'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setD(() => category = v ?? 'Refill'),
            ),
            const SizedBox(height: 10),
            TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Unit price (₱)')),
            const SizedBox(height: 10),
            TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity on hand')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: unit,
              decoration: const InputDecoration(labelText: 'Unit label'),
              items: const ['gallons', 'pcs', 'packs'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
              onChanged: (v) => setD(() => unit = v ?? 'gallons'),
            ),
            const SizedBox(height: 10),
            TextField(controller: reorderCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Reorder level (alert threshold)')),
          ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(existing == null ? 'Add' : 'Save')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    final double? price = double.tryParse(priceCtrl.text);
    final int? qty = int.tryParse(qtyCtrl.text);
    final int? reorder = int.tryParse(reorderCtrl.text);
    if (nameCtrl.text.trim().isEmpty || price == null || qty == null || reorder == null) {
      _toast(context, 'Please complete all fields with valid values.');
      return;
    }
    final InventoryItemModel model = InventoryItemModel(
      id: existing?.id ?? '',
      name: nameCtrl.text.trim(),
      category: category,
      unitPrice: price,
      quantityOnHand: qty,
      reorderLevel: reorder,
      unitLabel: unit,
    );
    try {
      if (existing == null) {
        await _service.addItem(model);
      } else {
        await _service.updateItem(existing.id, model);
      }
    } catch (e) {
      _toast(context, 'Save failed: $e');
    }
  }

  Future<void> _deleteItem(BuildContext context, InventoryItemModel item) async {
    final bool ok = await ConfirmDialog.show(
      context,
      title: 'Delete item',
      message: 'Remove "${item.name}" from inventory monitoring?',
      destructive: true,
      confirmLabel: 'Delete',
    );
    if (!ok || !context.mounted) return;
    await _service.deleteItem(item.id);
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
  }
}

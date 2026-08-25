import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/gallon_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/gallon_service.dart';
import '../../widgets/common_widgets.dart';

class AdminGallons extends StatefulWidget {
  const AdminGallons({super.key});

  @override
  State<AdminGallons> createState() => _AdminGallonsState();
}

class _AdminGallonsState extends State<AdminGallons> {
  final GallonService _service = GallonService();
  String _statusFilter = '';
  String _search = '';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GallonModel>>(
      stream: _service.streamGallons(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        List<GallonModel> gallons = snap.data!;
        final Map<String, int> counts = {};
        for (final GallonModel g in snap.data!) {
          counts[g.status] = (counts[g.status] ?? 0) + 1;
        }

        if (_statusFilter.isNotEmpty) gallons = gallons.where((g) => g.status == _statusFilter).toList();
        if (_search.isNotEmpty) {
          final q = _search.toLowerCase();
          gallons = gallons
              .where((g) =>
                  g.qrCodeValue.toLowerCase().contains(q) ||
                  (g.currentCustomerName ?? '').toLowerCase().contains(q))
              .toList();
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              flex: 3,
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                _countChip('All', '${snap.data!.length}', '', AppColors.textMuted),
                ...GallonStatus.all.map((s) => _countChip(GallonStatus.label(s), '${counts[s] ?? 0}', s, GallonStatus.color(s))),
              ]),
            ),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SearchField(hint: 'Search code or holder…', onChanged: (v) => setState(() => _search = v))),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Text('Each gallon is an individually tracked container with its own QR identity and movement history.',
                  style: AppTextStyles.muted),
            ),
            FilledButton.icon(
              onPressed: () => _registerDialog(),
              icon: const Icon(Icons.add_link_rounded, size: 18),
              label: const Text('Register gallons'),
            ),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: gallons.isEmpty
                ? const EmptyState(
                    icon: Icons.qr_code_2_rounded,
                    title: 'No gallons match',
                    message: 'Register physical gallons to generate QR codes you can print and attach.')
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 300, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55),
                    itemCount: gallons.length,
                    itemBuilder: (context, i) => _tile(gallons[i]),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _countChip(String label, String count, String status, Color color) {
    final bool selected = _statusFilter == status;
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = status),
      label: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ($count)', style: AppTextStyles.caption),
      ]),
      labelStyle: AppTextStyles.caption,
    );
  }

  Widget _tile(GallonModel g) {
    final Color c = GallonStatus.color(g.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _detailDialog(g),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Row(children: [
              Container(width: 34, height: 34,
                decoration: BoxDecoration(color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.qr_code_2_rounded, size: 19, color: c)),
              const SizedBox(width: 10),
              Expanded(child: Text(g.qrCodeValue, style: AppTextStyles.h3, overflow: TextOverflow.ellipsis)),
              IconButton(icon: const Icon(Icons.qr_code_scanner_rounded, size: 19), tooltip: 'Show QR', onPressed: () => _showQrDialog(g)),
            ]),
            const SizedBox(height: 8),
            StatusChip(status: g.status, label: GallonStatus.label(g.status), color: c),
            const SizedBox(height: 8),
            Text(g.currentCustomerName != null ? 'Holder: ${g.currentCustomerName}' : 'Unassigned',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.muted),
            Text('Updated ${AppFormatters.timeAgo(g.updatedAt ?? DateTime.now())}', style: AppTextStyles.caption),
          ]),
        ),
      ),
    );
  }

  Future<void> _registerDialog() async {
    final qtyCtrl = TextEditingController(text: '5');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Register new gallons'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Generates sequential QR identities (GLN-####). Print the codes and attach one to each physical container.'),
          const SizedBox(height: 14),
          TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'How many gallons?')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Generate QR codes')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final int? qty = int.tryParse(qtyCtrl.text);
    if (qty == null || qty <= 0 || qty > 100) {
      _toast('Enter a quantity from 1 to 100.');
      return;
    }
    try {
      final String actor = context.read<AuthProvider>().profile?.name ?? 'Admin';
      final List<String> created =
          await _service.registerGallons(qty, byUserName: actor);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${created.length} gallons registered.')));
      _printableSheet(created);
    } catch (e) {
      _toast('Registration failed: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.danger));
  }

  void _printableSheet(List<String> codes) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 640, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Text('QR labels · ${codes.length} gallons', style: AppTextStyles.h3.copyWith(color: Colors.black87)),
                  const Spacer(),
                  OutlinedButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: codes.join('\n'))); },
                      icon: const Icon(Icons.copy_rounded, size: 16), label: const Text('Copy codes')),
                ])),
            Expanded(
              child: GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                children: codes.map((c) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      QrImageView(data: c, version: QrVersions.auto, size: 110, backgroundColor: Colors.white),
                      const SizedBox(height: 4),
                      Text(c, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black87)),
                    ]),
                  );
                }).toList(),
              ),
            ),
            Padding(padding: const EdgeInsets.all(14),
                child: SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')))),
          ]),
        ),
      ),
    );
  }

  void _showQrDialog(GallonModel g) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('QR — ${g.qrCodeValue}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          QrImageView(data: g.qrCodeValue, version: QrVersions.auto, size: 200, backgroundColor: Colors.white),
          const SizedBox(height: 12),
          Text('This QR contains only the gallon ID. All records are resolved securely from Firestore.',
              textAlign: TextAlign.center, style: AppTextStyles.caption),
        ]),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _detailDialog(GallonModel initial) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 18),
        child: SingleChildScrollView(
          child: StreamBuilder<GallonModel?>(
            stream: _service.streamGallonById(initial.id),
            builder: (ctx, gSnap) {
              final GallonModel current = gSnap.data ?? initial;
              final List<String> nexts = GallonStatus.allowedTransitions[current.status] ?? [];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  QrImageView(data: current.qrCodeValue, version: QrVersions.auto, size: 64, backgroundColor: Colors.white),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(current.qrCodeValue, style: AppTextStyles.h2),
                    StatusChip(status: current.status, label: GallonStatus.label(current.status), color: GallonStatus.color(current.status)),
                  ])),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                ]),
                const SizedBox(height: 14),
                Card(color: AppColors.surfaceAlt, margin: EdgeInsets.zero,
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  InfoRow(label: 'Current holder', value: current.currentCustomerName ?? '—'),
                  InfoRow(label: 'Linked order', value: current.currentOrderId ?? '—'),
                  InfoRow(label: 'Registered', value: AppFormatters.dateTime(current.createdAt ?? DateTime.now())),
                  InfoRow(label: 'Last updated', value: AppFormatters.dateTime(current.updatedAt ?? DateTime.now())),
                ]))),
                const SizedBox(height: 14),
                Text('Move to status', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ...nexts.map((s) => OutlinedButton(
                        onPressed: () async {
                          try {
                            await _service.transitionGallon(
                              gallon: current,
                              newStatus: s,
                              byUserName: ctx.read<AuthProvider>().profile?.name ?? 'Admin',
                            );
                          } catch (e) {
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                  content: Text('$e'.replaceFirst('Exception: ', '')),
                                  backgroundColor: AppColors.danger));
                            }
                          }
                        },
                        child: Text(GallonStatus.label(s)),
                      )),
                  if (nexts.isEmpty) Text('Terminal state. No further transitions.', style: AppTextStyles.muted),
                ]),
                const SizedBox(height: 16),
                Text('History', style: AppTextStyles.h3),
                const SizedBox(height: 6),
                StreamBuilder<List<GallonHistoryEntry>>(
                  stream: _service.streamHistory(current.id),
                  builder: (ctx, hSnap) {
                    final entries = hSnap.data ?? [];
                    if (entries.isEmpty) return Text('No history recorded yet.', style: AppTextStyles.muted);
                    return Column(children: entries.take(12).map((h) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history_rounded, size: 17, color: GallonStatus.color(h.toStatus)),
                      title: Text(h.fromStatus == null || h.fromStatus!.isEmpty
                          ? '${h.action} → ${GallonStatus.label(h.toStatus)}'
                          : '${GallonStatus.label(h.fromStatus!)} → ${GallonStatus.label(h.toStatus)}',
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
                      subtitle: Text([h.byUserName, h.customerName, h.note].whereType<String>().where((s) => s.isNotEmpty).join(' · '), style: AppTextStyles.caption),
                      trailing: Text(AppFormatters.shortDate(h.timestamp ?? DateTime.now()), style: AppTextStyles.caption),
                    )).toList());
                  },
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }
}

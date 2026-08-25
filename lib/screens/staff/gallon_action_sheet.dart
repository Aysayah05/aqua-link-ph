import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../models/gallon_model.dart';
import '../../services/gallon_service.dart';
import '../../widgets/common_widgets.dart';

Future<void> showGallonActionSheet(
    BuildContext context, GallonModel initial, String actorName, GallonService service) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    builder: (sheetCtx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.of(sheetCtx).viewInsets.bottom + 18),
      child: SingleChildScrollView(
        child: StreamBuilder<GallonModel?>(
          stream: service.streamGallonById(initial.id),
          builder: (ctx, gSnap) {
            final GallonModel g = gSnap.data ?? initial;
            final List<String> nexts = GallonStatus.allowedTransitions[g.status] ?? [];
            return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Icon(Icons.qr_code_2_rounded, size: 30, color: GallonStatus.color(g.status)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.qrCodeValue, style: AppTextStyles.h2),
                  StatusChip(status: g.status, label: GallonStatus.label(g.status), color: GallonStatus.color(g.status)),
                ])),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
              ]),
              const SizedBox(height: 14),
              Card(color: AppColors.surfaceAlt, margin: EdgeInsets.zero,
                  child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                InfoRow(label: 'Current holder', value: g.currentCustomerName ?? '—'),
                InfoRow(label: 'Linked order', value: g.currentOrderId ?? '—'),
                InfoRow(label: 'Last updated', value: AppFormatters.timeAgo(g.updatedAt ?? DateTime.now())),
              ]))),
              const SizedBox(height: 16),
              Text('Authorized actions for this gallon', style: AppTextStyles.h3),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children:
                nexts.map((s) => FilledButton.tonalIcon(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                  label: Text('Mark ${GallonStatus.label(s)}'),
                  onPressed: () async {
                    try {
                      await service.transitionGallon(
                          gallon: g, newStatus: s, byUserName: actorName);
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                            content: Text('${g.qrCodeValue} → ${GallonStatus.label(s)}')));
                      }
                    } catch (e) {
                      if (sheetCtx.mounted) {
                        ScaffoldMessenger.of(sheetCtx).showSnackBar(SnackBar(
                            content: Text('$e'.replaceFirst('Exception: ', '')),
                            backgroundColor: AppColors.danger));
                      }
                    }
                  },
                )).toList()),
              if (nexts.isEmpty)
                Text('${GallonStatus.label(g.status)} is a terminal state — no transitions allowed.',
                    style: AppTextStyles.muted),
              const SizedBox(height: 16),
              Text('Movement history', style: AppTextStyles.h3),
              const SizedBox(height: 6),
              StreamBuilder<List<GallonHistoryEntry>>(
                stream: service.streamHistory(g.id),
                builder: (ctx, hSnap) {
                  final entries = hSnap.data ?? [];
                  if (entries.isEmpty) return Text('No history yet.', style: AppTextStyles.muted);
                  return ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220),
                    child: ListView(shrinkWrap: true, children: entries.take(15).map((h) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.history_rounded, size: 16, color: GallonStatus.color(h.toStatus)),
                      title: Text(h.fromStatus == null || h.fromStatus!.isEmpty
                          ? '${h.action} → ${GallonStatus.label(h.toStatus)}'
                          : '${GallonStatus.label(h.fromStatus!)} → ${GallonStatus.label(h.toStatus)}',
                          style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
                      subtitle: Text([h.byUserName, h.customerName].whereType<String>().where((s) => s.isNotEmpty).join(' · '), style: AppTextStyles.caption),
                      trailing: Text(AppFormatters.shortDate(h.timestamp ?? DateTime.now()), style: AppTextStyles.caption),
                    )).toList(),
                  ));
                },
              ),
            ]);
          },
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/gallon_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/gallon_service.dart';
import '../../widgets/common_widgets.dart';

class CustomerGallons extends StatelessWidget {
  const CustomerGallons({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final String uid = auth.profile?.uid ?? '';

    return StreamBuilder<List<GallonModel>>(
      stream: uid.isEmpty ? null : GallonService().streamGallonsForCustomer(uid),
      builder: (context, snap) {
        if (uid.isEmpty) {
          return const EmptyState(icon: Icons.water_drop_outlined, title: 'No account link', message: 'Gallon tracking needs a registered customer account.');
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final List<GallonModel> gallons = snap.data!;
        final List<GallonModel> active = gallons
            .where((g) => g.status == GallonStatus.withCustomer || g.status == GallonStatus.outForDelivery)
            .toList();

        return ListView(padding: const EdgeInsets.only(bottom: 20), children: [
          Card(
            child: Padding(padding: const EdgeInsets.all(18), child:
              Row(children: [
                Container(width: 46, height: 46, decoration:
                  BoxDecoration(color: AppColors.primary.withOpacity(0.14), borderRadius: BorderRadius.circular(13)),
                  child: Icon(Icons.water_drop_rounded, color: AppColors.primary, size: 24)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('You have ${active.length} water gallon(s)', style: AppTextStyles.h3),
                  Text('Please return empty containers so they can be refilled and tracked.', style: AppTextStyles.muted),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          if (gallons.isEmpty)
            const EmptyState(
                icon: Icons.inventory_rounded,
                title: 'No gallons linked to you',
                message: 'When a delivery with QR-tracked gallons is prepared for you, each container appears here.')
          else
            ...gallons.map((g) => _tile(g)),
          const SizedBox(height: 12),
          Card(color: AppColors.surfaceAlt,
            child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 19, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(child: Text('Every gallon carries a unique QR code. The station scans it at dispatch and return — so nothing gets lost or unaccounted for.', style: AppTextStyles.muted)),
            ]))),
        ]);
      },
    );
  }

  Widget _tile(GallonModel g) {
    final Color c = GallonStatus.color(g.status);
    final String friendly;
    switch (g.status) {
      case GallonStatus.outForDelivery:
        friendly = 'On the way to you right now';
        break;
      case GallonStatus.withCustomer:
        friendly = 'With you · awaiting return';
        break;
      case GallonStatus.returned:
        friendly = 'Returned ✓ thank you!';
        break;
      default:
        friendly = GallonStatus.label(g.status);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(width: 38, height: 38,
          decoration: BoxDecoration(color: c.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.water_drop_rounded, color: c, size: 20)),
        title: Text(g.qrCodeValue, style: AppTextStyles.bodyStrong),
        subtitle: Text(friendly, style: AppTextStyles.muted),
        trailing: StatusChip(status: g.status, label: GallonStatus.label(g.status), color: c),
      )),
    );
  }
}

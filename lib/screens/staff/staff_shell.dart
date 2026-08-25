import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_shell.dart';
import 'staff_dashboard.dart';
import 'staff_delivery.dart';
import 'staff_orders.dart';
import 'staff_scanner.dart';
import 'staff_transactions.dart';

class StaffShell extends StatelessWidget {
  const StaffShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? profile = auth.profile;

    return PortalShell(
      title: 'Staff',
      profile: profile,
      accentColor: AppColors.accent,
      onSignOut: () => context.read<AuthProvider>().signOut(),
      items: [
        PortalNavItem(icon: Icons.speed_rounded, label: 'Today', body: StaffDashboard()),
        PortalNavItem(icon: Icons.receipt_long_rounded, label: 'Orders', body: StaffOrders()),
        PortalNavItem(icon: Icons.local_shipping_rounded, label: 'Deliveries', body: StaffDelivery()),
        PortalNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan Gallon', body: StaffScanner()),
        PortalNavItem(icon: Icons.fact_check_rounded, label: 'Transactions', body: StaffTransactions()),
      ],
    );
  }
}

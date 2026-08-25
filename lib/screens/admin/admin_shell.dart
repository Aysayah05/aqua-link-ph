import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_shell.dart';
import 'admin_customers.dart';
import 'admin_dashboard.dart';
import 'admin_expenses.dart';
import 'admin_gallons.dart';
import 'admin_inventory.dart';
import 'admin_orders.dart';
import 'admin_reports.dart';
import 'admin_sales.dart';
import 'admin_settings.dart';
import 'admin_staff.dart';

class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? profile = auth.profile;

    return PortalShell(
      title: 'Admin',
      profile: profile,
      accentColor: AppColors.primary,
      onSignOut: () => context.read<AuthProvider>().signOut(),
      items: [
        PortalNavItem(icon: Icons.dashboard_rounded, label: 'Dashboard', body: AdminDashboard()),
        PortalNavItem(icon: Icons.receipt_long_rounded, label: 'Orders', body: AdminOrders()),
        PortalNavItem(icon: Icons.people_alt_rounded, label: 'Customers', body: AdminCustomers()),
        PortalNavItem(icon: Icons.qr_code_2_rounded, label: 'Gallons & QR', body: AdminGallons()),
        PortalNavItem(icon: Icons.inventory_2_rounded, label: 'Inventory', body: AdminInventory()),
        PortalNavItem(icon: Icons.point_of_sale_rounded, label: 'Sales', body: AdminSales()),
        PortalNavItem(icon: Icons.payments_rounded, label: 'Expenses', body: AdminExpenses()),
        PortalNavItem(icon: Icons.query_stats_rounded, label: 'Reports', body: AdminReports()),
        PortalNavItem(icon: Icons.badge_rounded, label: 'Staff', body: AdminStaff()),
        PortalNavItem(icon: Icons.settings_rounded, label: 'Settings', body: AdminSettings()),
      ],
    );
  }
}

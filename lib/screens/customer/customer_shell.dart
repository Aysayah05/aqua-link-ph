import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/portal_shell.dart';
import 'customer_gallons.dart';
import 'customer_home.dart';
import 'customer_new_order.dart';
import 'customer_orders.dart';

class CustomerShell extends StatelessWidget {
  const CustomerShell({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthProvider auth = context.watch<AuthProvider>();
    final UserModel? profile = auth.profile;

    return PortalShell(
      title: 'Aqua Link',
      profile: profile,
      accentColor: AppColors.accent,
      onSignOut: () => context.read<AuthProvider>().signOut(),
      items: const [
        PortalNavItem(icon: Icons.home_rounded, label: 'Home', body: CustomerHome()),
        PortalNavItem(icon: Icons.water_drop_rounded, label: 'Order Water', body: CustomerNewOrder()),
        PortalNavItem(icon: Icons.local_shipping_rounded, label: 'My Orders', body: CustomerOrders()),
        PortalNavItem(icon: Icons.inventory_rounded, label: 'My Gallons', body: CustomerGallons()),
      ],
    );
  }
}

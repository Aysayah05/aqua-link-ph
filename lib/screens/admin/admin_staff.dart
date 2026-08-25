import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/common_widgets.dart';

class AdminStaff extends StatelessWidget {
  AdminStaff({super.key});

  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection(Collections.users).snapshots(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorState(error: snap.error);
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());

        final List<UserModel> staff =
            snap.data!.docs.map(UserModel.fromDoc).where((u) => u.isAdmin || u.isStaff).toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text('Create staff accounts for station employees. Staff can process orders, scan gallons, and verify payments — but never access financial reports.',
                    style: AppTextStyles.muted)),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _addAccountDialog(context),
              icon: const Icon(Icons.person_add_alt_rounded, size: 18),
              label: const Text('Add account'),
            ),
          ]),
          const SizedBox(height: 14),
          Text('${staff.length} admin & staff account(s)', style: AppTextStyles.muted),
          const SizedBox(height: 8),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: staff.isEmpty
                  ? const EmptyState(icon: Icons.badge_outlined, title: 'No staff accounts yet')
                  : ListView.separated(
                      itemCount: staff.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                      itemBuilder: (context, i) {
                        final UserModel u = staff[i];
                        final AuthProvider auth = context.watch<AuthProvider>();
                        final bool isSelf = auth.profile?.uid == u.uid;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                          leading: CircleAvatar(
                            radius: 19,
                            backgroundColor: u.isAdmin ? AppColors.purple.withOpacity(0.2) : AppColors.primarySoft,
                            child: Icon(u.isAdmin ? Icons.admin_panel_settings_rounded : Icons.badge_rounded,
                                size: 19, color: u.isAdmin ? AppColors.purple : AppColors.accent),
                          ),
                          title: Row(children: [
                            Expanded(child: Text(u.name, style: AppTextStyles.bodyStrong)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                              child: Text(Roles.label(u.role), style: AppTextStyles.caption),
                            ),
                          ]),
                          subtitle: Text(u.email, style: AppTextStyles.muted),
                          trailing: isSelf
                              ? const Text('You', style: AppTextStyles.caption)
                              : SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('', style: TextStyle(fontSize: 0)),
                                  value: !u.disabled,
                                  activeColor: AppColors.success,
                                  onChanged: (active) =>
                                      FirebaseFirestore.instance.collection(Collections.users).doc(u.uid).update({'disabled': !active}),
                                ),
                        );
                      },
                    ),
            ),
          ),
        ]);
      },
    );
  }

  Future<void> _addAccountDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String role = Roles.staff;
    final phoneCtrl = TextEditingController();

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        title: const Text('Add staff / admin account'),
        content: SizedBox(width: 380, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: Roles.staff, label: Text('Staff')),
              ButtonSegment(value: Roles.admin, label: Text('Admin')),
            ],
            selected: {role},
            onSelectionChanged: (s) => setD(() => role = s.first),
          ),
          const SizedBox(height: 12),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 10),
          TextField(controller: emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email address')),
          const SizedBox(height: 10),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile number')),
          const SizedBox(height: 10),
          TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Temporary password', helperText: 'At least 6 characters')),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create account')),
        ],
      )),
    );
    if (ok != true || !context.mounted) return;
    if (Validators.required(nameCtrl.text) != null ||
        Validators.email(emailCtrl.text) != null ||
        Validators.password(passCtrl.text) != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check the fields and try again.'), backgroundColor: AppColors.danger));
      return;
    }
    final AuthResult result = await _auth.createStaffAccount(
      name: nameCtrl.text,
      email: emailCtrl.text,
      password: passCtrl.text,
      role: role,
      phone: phoneCtrl.text,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.success
          ? 'Account created. Share the credentials with the employee.'
          : (result.message ?? 'Failed to create account.')),
      backgroundColor: result.success ? AppColors.success : AppColors.danger,
    ));
  }
}

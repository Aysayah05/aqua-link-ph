import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_text_styles.dart';
import '../models/user_model.dart';

class PortalNavItem {
  const PortalNavItem({required this.icon, required this.label, required this.body});
  final IconData icon;
  final String label;
  final Widget body;
}

class PortalShell extends StatefulWidget {
  const PortalShell({
    super.key,
    required this.title,
    required this.items,
    required this.profile,
    required this.accentColor,
    this.appBarActions,
    this.floatingActionButton,
    this.onSignOut,
  });

  final String title;
  final List<PortalNavItem> items;
  final UserModel? profile;
  final Color accentColor;
  final List<Widget>? appBarActions;
  final Widget? floatingActionButton;
  final VoidCallback? onSignOut;

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _index = 0;

  bool get isWide => MediaQuery.of(context).size.width >= 1000;

  void _select(int i) {
    setState(() => _index = i);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = widget.items[_index].body;
    return Scaffold(
      appBar: AppBar(
        title: Text(isWide ? '' : widget.items[_index].label),
        leading: isWide
            ? null
            : Builder(builder: (ctx) => IconButton(icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        automaticallyImplyLeading: !isWide,
        actions: [
          ...?widget.appBarActions,
          const SizedBox(width: 8),
        ],
      ),
      drawer: isWide ? null : _buildDrawer(context),
      floatingActionButton: widget.floatingActionButton,
      body: isWide
          ? Row(children: [
              _buildSidebar(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  child: content,
                ),
              ),
            ])
          : RefreshIndicator(
              onRefresh: () async {
                await Future<void>.delayed(const Duration(milliseconds: 300));
              },
              child: Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 0), child: content),
            ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 244,
      margin: const EdgeInsets.only(top: 4, bottom: 12, left: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Aqua Link PH', style: AppTextStyles.h3.copyWith(fontSize: 15)),
                  Text('Edelycalie Station', style: AppTextStyles.caption),
                ]),
              ),
            ]),
          ),
          Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: widget.items.length,
              itemBuilder: (ctx, i) {
                final bool selected = i == _index;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Material(
                    color: selected ? widget.accentColor.withOpacity(0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => _index = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? widget.accentColor.withOpacity(0.35) : Colors.transparent),
                        ),
                        child: Row(children: [
                          Icon(widget.items[i].icon,
                              size: 19,
                              color: selected ? widget.accentColor : AppColors.textMuted),
                          const SizedBox(width: 11),
                          Text(widget.items[i].label,
                              style: AppTextStyles.bodyStrong.copyWith(
                                color: selected ? AppColors.textPrimary : AppColors.textMuted,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              )),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          _userFooter(context),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(child: _buildSidebarContent(context)),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Aqua Link PH', style: AppTextStyles.h3.copyWith(fontSize: 15)),
                Text('Edelycalie Station', style: AppTextStyles.caption),
              ]),
            ),
          ]),
        ),
        Divider(height: 1, color: AppColors.border),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: widget.items.length,
            itemBuilder: (ctx, i) {
              final bool selected = i == _index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Material(
                  color: selected ? widget.accentColor.withOpacity(0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _select(i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                      child: Row(children: [
                        Icon(widget.items[i].icon,
                            size: 19,
                            color: selected ? widget.accentColor : AppColors.textMuted),
                        const SizedBox(width: 11),
                        Text(widget.items[i].label,
                            style: AppTextStyles.bodyStrong.copyWith(
                              color: selected ? AppColors.textPrimary : AppColors.textMuted,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            )),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _userFooter(BuildContext context) {
    final UserModel? profile = widget.profile;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(
          radius: 17,
          backgroundColor: AppColors.primarySoft,
          backgroundImage: null,
          child: Text(profile?.initials() ?? '?', style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(profile?.name ?? 'User',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodyStrong),
            Text(Roles.label(profile?.role ?? ''), style: AppTextStyles.caption),
          ]),
        ),
        IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout_rounded, size: 19, color: AppColors.textMuted),
          onPressed: () async {
            final bool ok = await ConfirmDialogHelper.signOutConfirm(context);
            if (ok && context.mounted) {
              Navigator.popUntil(context, (r) => r.isFirst);
              widget.onSignOut?.call();
            }
          },
        ),
      ]),
    );
  }
}

class ConfirmDialogHelper {
  static Future<bool> signOutConfirm(BuildContext context) async {
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out of Aqua Link PH?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    return result ?? false;
  }
}

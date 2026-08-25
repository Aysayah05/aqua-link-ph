import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _loading = false;
  bool _obscure = true;
  bool _checkedBootstrap = false;
  bool _canClaimAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkBootstrap();
  }

  Future<void> _checkBootstrap() async {
    final AuthService auth = AuthService();
    final bool available = await auth.canClaimAdmin();
    if (!mounted) return;
    setState(() {
      _canClaimAdmin = available;
      _checkedBootstrap = true;
    });
  }

  @override
  void dispose() {
    for (final TextEditingController c in [
      _nameCtrl,
      _emailCtrl,
      _phoneCtrl,
      _addressCtrl,
      _passwordCtrl,
      _confirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(AuthProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final AuthService service = AuthService();
    final result = await service.registerCustomer(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message ?? 'Registration failed'),
        backgroundColor: AppColors.danger,
      ));
      setState(() => _loading = false);
      return;
    }

    await _checkBootstrap();
    if (_canClaimAdmin) {
      final String uid = service.currentUser?.uid ?? '';
      if (uid.isNotEmpty && mounted) {
        final bool claim = await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text('First account detected'),
                content: const Text(
                    'No administrator exists yet for this station.\n\nMake this account the ADMINISTRATOR of Aqua Link PH?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep as customer')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      child: const Text('Become admin')),
                ],
              ),
            ) ??
            false;
        if (claim) {
          final AuthResult claimed =
              await service.claimAdminForCurrentUser(uid);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(claimed.success
                ? 'You are now the administrator. Welcome!'
                : (claimed.message ?? 'Claim failed')),
            backgroundColor:
                claimed.success ? AppColors.success : AppColors.danger,
          ));
          setState(() => _loading = false);
          return;
        }
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.maybePop(context)),
        title: const Text('Create customer account'),
      ),
      body: Consumer<AuthProvider>(builder: (context, auth, _) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                color: AppColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 23),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Join ${AppConstants.appName}', style: AppTextStyles.h2),
                            Text('Order water from ${AppConstants.stationName}',
                                style: AppTextStyles.caption),
                          ]),
                        ),
                      ]),
                      if (_checkedBootstrap && _canClaimAdmin) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.1),
                            border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(children: [
                            Icon(Icons.admin_panel_settings_rounded, color: AppColors.warning, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  'Setup mode: the first account created can become the system administrator.',
                                  style: AppTextStyles.muted),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 18),
                      TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Full name'),
                          validator: (v) => Validators.required(v, field: 'Full name')),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'Email address'),
                          validator: Validators.email),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Mobile number', hintText: '09XXXXXXXXX'),
                          validator: Validators.phone),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: _addressCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              labelText: 'Delivery address', hintText: 'House no., Street, Barangay'),
                          validator: (v) => Validators.required(v, field: 'Delivery address')),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                              onPressed: () => setState(() => _obscure = !_obscure),
                            ),
                          ),
                          validator: Validators.password),
                      const SizedBox(height: 13),
                      TextFormField(
                          controller: _confirmCtrl,
                          obscureText: _obscure,
                          onFieldSubmitted: (_) => _submit(auth),
                          decoration: const InputDecoration(labelText: 'Confirm password'),
                          validator: (v) =>
                              v == _passwordCtrl.text ? null : 'Passwords do not match'),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _loading ? null : () => _submit(auth),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                          child: _loading
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                              : const Text('Create account'),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

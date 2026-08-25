import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final result =
        await auth.signIn(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (!mounted) return;
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message ?? 'Sign in failed'),
        backgroundColor: AppColors.danger,
      ));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Consumer<AuthProvider>(builder: (context, auth, _) {
        return LayoutBuilder(builder: (context, constraints) {
          final bool wideScreen = constraints.maxWidth >= 900;
          return Row(children: [
            if (wideScreen) Expanded(child: _brandPanel()),
            Expanded(child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: _loginCard(context, auth)))),
          ]);
        });
      }),
    );
  }

  Widget _brandPanel() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primarySoft, AppColors.background],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 32),
            Text('Aqua Link PH', style: AppTextStyles.h1.copyWith(fontSize: 40)),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(AppConstants.stationTagline,
                  style: AppTextStyles.muted.copyWith(fontSize: 15, height: 1.5)),
            ),
            const SizedBox(height: 40),
            ...[
              (Icons.qr_code_scanner_rounded, 'QR-based gallon tracking'),
              (Icons.local_shipping_rounded, 'Delivery coordination & tracking'),
              (Icons.query_stats_rounded, 'Sales monitoring & profit analytics'),
            ].map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Icon(item.$1, color: AppColors.accent, size: 20),
                    const SizedBox(width: 12),
                    Text(item.$2, style: AppTextStyles.bodyStrong),
                  ]),
                )),
          ],
        ),
      ),
    );
  }

  Widget _loginCard(BuildContext context, AuthProvider auth) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Card(
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppColors.primary, AppColors.accent]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              Text('Welcome back', textAlign: TextAlign.center, style: AppTextStyles.h1),
              const SizedBox(height: 6),
              Text('Sign in to ${AppConstants.stationName}',
                  textAlign: TextAlign.center, style: AppTextStyles.muted),
              const SizedBox(height: 26),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: 'Email address', prefixIcon: Icon(Icons.alternate_email_rounded, size: 20)),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                onFieldSubmitted: (_) => _submit(auth),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: _loading ? null : () => _submit(auth),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('No account yet? ', style: AppTextStyles.muted),
                GestureDetector(
                  onTap: () => Navigator.pushNamed(context, '/register'),
                  child: Text('Register as customer', style: AppTextStyles.bodyStrong.copyWith(color: AppColors.accent)),
                ),
              ]),
              const SizedBox(height: 8),
              Text('Staff and admin accounts are issued by the station administrator.',
                  textAlign: TextAlign.center, style: AppTextStyles.caption),
            ]),
          ),
        ),
      ),
    );
  }
}

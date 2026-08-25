import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../screens/admin/admin_shell.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/customer/customer_shell.dart';
import '../screens/error/access_denied_screen.dart';
import '../screens/staff/staff_shell.dart';

class AppRouter {
  AppRouter._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String admin = '/admin';
  static const String staff = '/staff';
  static const String customer = '/customer';

  static Route<dynamic> onGenerateRoute(RouteSettings settings, AuthProvider auth) {
    final String name = settings.name ?? splash;
    Widget page;

    switch (name) {
      case login:
        page = _guard(auth, LoginScreen(), null);
        break;
      case register:
        page = _guard(auth, RegisterScreen(), Roles.customer);
        break;
      case admin:
        page = _guard(auth, const AdminShell(), Roles.admin);
        break;
      case staff:
        page = _guard(auth, const StaffShell(), Roles.staff);
        break;
      case customer:
        page = _guard(auth, const CustomerShell(), Roles.customer);
        break;
      case splash:
      default:
        page = _root(auth);
    }
    return MaterialPageRoute<dynamic>(settings: settings, builder: (_) => page);
  }

  static Widget _root(AuthProvider auth) {
    if (auth.status == AuthStatus.misconfigured) {
      return const SizedBox.shrink();
    }
    switch (auth.status) {
      case AuthStatus.uninitialized:
        return const _SplashGate();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
      case AuthStatus.authenticated:
      case AuthStatus.misconfigured:
        return _portalFor(auth);
    }
  }

  static Widget _portalFor(AuthProvider auth) {
    final String? role = auth.profile?.role;
    if (!auth.isSignedIn || role == null) return const _SplashGate();
    switch (role) {
      case Roles.admin:
        return const AdminShell();
      case Roles.staff:
        return const StaffShell();
      case Roles.customer:
        return const CustomerShell();
      default:
        return const AccessDeniedScreen(expectedRole: null);
    }
  }

  static Widget _guard(AuthProvider auth, Widget page, String? requiredRole) {
    if (!auth.isSignedIn) return const LoginScreen();
    if (requiredRole != null && auth.profile!.role != requiredRole) {
      return AccessDeniedScreen(expectedRole: requiredRole);
    }
    return page;
  }

  static void goHome(BuildContext context, AuthProvider auth) {
    Navigator.pushNamedAndRemoveUntil(context, splash, (_) => false);
  }
}

class _SplashGate extends StatefulWidget {
  const _SplashGate();

  @override
  State<_SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<_SplashGate> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: Tween<double>(begin: 0.55, end: 1).animate(_pulse),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2F80ED), Color(0xFF27C6DA)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 22),
            Text('Aqua Link PH', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Edelycalie Water Refilling Station'),
            const SizedBox(height: 32),
            const SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 2.5)),
          ],
        ),
      ),
    );
  }
}

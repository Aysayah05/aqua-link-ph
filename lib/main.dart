import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart' as fb_options;
import 'providers/auth_provider.dart';
import 'routes/app_router.dart';
import 'screens/error/firebase_config_screen.dart';

bool _isFirebaseConfigured(FirebaseOptions options) {
  const List<String> placeholders = [
    'YOUR_API_KEY',
    'DEMO_KEY',
    'AIzaSyPLACEHOLDER',
    '',
  ];
  return !placeholders.contains(options.apiKey) && options.projectId.isNotEmpty;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool configured = false;
  try {
    configured = _isFirebaseConfigured(fb_options.DefaultFirebaseOptions.currentPlatform);
    if (configured) {
      await Firebase.initializeApp(
          options: fb_options.DefaultFirebaseOptions.currentPlatform);
    }
  } catch (_) {
    configured = false;
  }
  runApp(AquaLinkApp(firebaseReady: configured));
}

class AquaLinkApp extends StatelessWidget {
  const AquaLinkApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) {
        final AuthProvider provider = AuthProvider(FirebaseFirestore.instance);
        if (firebaseReady) {
          provider.init();
        } else {
          provider.markMisconfigured();
        }
        return provider;
      },
      child: Consumer<AuthProvider>(builder: (BuildContext context, AuthProvider auth, _) {
        return MaterialApp(
          title: 'Aqua Link PH',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
          onGenerateRoute: (RouteSettings settings) => AppRouter.onGenerateRoute(settings, auth),
          builder: (BuildContext context, Widget? child) {
            if (auth.status == AuthStatus.misconfigured) {
              return const FirebaseConfigScreen();
            }
            if (auth.status == AuthStatus.unauthenticated && auth.errorMessage != null) {
              final String message = auth.errorMessage!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(message),
                  backgroundColor: AppColors.danger,
                ));
              });
              Future<void>.delayed(Duration.zero, () => auth.clearTransientError());
            }
            return child ?? const SizedBox.shrink();
          },
        );
      }),
    );
  }
}

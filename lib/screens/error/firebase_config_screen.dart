import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class FirebaseConfigScreen extends StatelessWidget {
  const FirebaseConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 32),
                      const SizedBox(width: 12),
                      Text('Firebase setup required', style: AppTextStyles.h1),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      'Aqua Link PH is built and ready, but it is not connected to a Firebase project yet. '
                      'Complete these one-time steps:',
                      style: AppTextStyles.muted,
                    ),
                    const SizedBox(height: 20),
                    ..._steps.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                alignment: Alignment.center,
                                child: Text('${_steps.indexOf(s) + 1}',
                                    style: AppTextStyles.bodyStrong.copyWith(color: AppColors.accent)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: s),
                            ],
                          ),
                        )),
                    const Divider(),
                    Text(
                      'After flutterfire configure finishes, hot-restart the app. '
                      'Full details are in SETUP_GUIDE.md inside this project.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final List<Widget> _steps = [
    const Text.rich(TextSpan(style: AppTextStyles.body, children: [
      TextSpan(text: 'Create a Firebase project', style: AppTextStyles.bodyStrong),
      TextSpan(text: ' at console.firebase.google.com'),
    ])),
    const Text.rich(TextSpan(style: AppTextStyles.body, children: [
      TextSpan(text: 'Enable ', style: AppTextStyles.body),
      TextSpan(text: 'Authentication → Email/Password', style: AppTextStyles.bodyStrong),
      TextSpan(text: ' and create a ', style: AppTextStyles.body),
      TextSpan(text: 'Cloud Firestore database', style: AppTextStyles.bodyStrong),
      TextSpan(text: ' (production mode).'),
    ])),
    const Text.rich(TextSpan(style: AppTextStyles.body, children: [
      TextSpan(text: 'In the project terminal run:\n', style: AppTextStyles.body),
      TextSpan(
        text: 'dart pub global activate flutterfire_cli\nflutterfire configure',
        style: TextStyle(fontFamily: 'monospace', color: Color(0xFF27C6DA)),
      ),
    ])),
    const Text.rich(TextSpan(style: AppTextStyles.body, children: [
      TextSpan(
          text:
              'Select your project, keep web enabled — it writes lib/firebase_options.dart automatically.',
          style: AppTextStyles.body),
    ])),
    const Text.rich(TextSpan(style: AppTextStyles.body, children: [
      TextSpan(text: 'Publish the security rules:\n', style: AppTextStyles.body),
      TextSpan(
        text: 'firebase deploy --only firestore:rules',
        style: TextStyle(fontFamily: 'monospace', color: Color(0xFF27C6DA)),
      ),
    ])),
  ];
}

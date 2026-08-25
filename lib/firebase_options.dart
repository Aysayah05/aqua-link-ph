// Firebase configuration for Aqua Link PH.
//
// THIS FILE IS A TEMPLATE. Run `flutterfire configure` to generate the real
// values automatically (recommended), or paste your web app config manually.
//
// Steps:
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure
//   3. Select your Firebase project and keep "web" enabled.
//
// The app detects placeholder values below and shows a setup guide screen
// until real credentials are provided.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'Aqua Link PH is a Flutter Web build. Run it in Chrome or Edge.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_PROJECT_ID.firebaseapp.com',
    storageBucket: 'YOUR_PROJECT_ID.appspot.com',
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aqua_link_ph/core/theme/app_theme.dart';

void main() {
  test('App theme builds with dark scheme', () {
    final theme = AppTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.colorScheme.primary, isNotNull);
  });
}

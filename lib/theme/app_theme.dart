import 'package:flutter/material.dart';

abstract final class AppColors {
  static const energized = Color(0xFF2E9E44);
  static const wire = Color(0xFF6B7280);
  static const lampOn = Color(0xFFFFC107);
  static const lampOff = Color(0xFF4B5563);
}

ThemeData buildAppTheme() => ThemeData(
      colorSchemeSeed: const Color(0xFF1565C0),
      useMaterial3: true,
    );

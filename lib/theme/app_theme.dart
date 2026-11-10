import 'package:flutter/material.dart';

abstract final class AppColors {
  static const energized = Color(0xFF2E9E44);
  static const wire = Color(0xFF6B7280);
  static const lampOn = Color(0xFFFFC107);
  static const lampOff = Color(0xFF4B5563);
}

/// Look of the ladder area (white page, thin blue wires, classic sans text).
abstract final class LadderStyle {
  static const wire = Color(0xFF0000A0);
  static const rungNumber = Color(0xFF0000FF);
  static const energized = Color(0xFF00C000);
  static const titleBand = Color(0xFF00FF00);
  static const commentBand = Color(0xFFFFFF99);
  static const selection = Color(0xFF000000);

  static const text = TextStyle(
    fontFamily: 'Arial',
    fontFamilyFallback: ['Liberation Sans', 'Helvetica', 'Tahoma', 'Roboto'],
    fontSize: 11,
    height: 1.2,
    color: Color(0xFF000000),
  );
}

ThemeData buildAppTheme() => ThemeData(
      colorSchemeSeed: const Color(0xFF1565C0),
      useMaterial3: true,
    );

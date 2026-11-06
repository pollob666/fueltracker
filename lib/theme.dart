// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const Color _primaryColor = Color(0xFF22484e);

  static final _defaultLightColorScheme =
      ColorScheme.fromSeed(seedColor: _primaryColor);
  static final _defaultDarkColorScheme = ColorScheme.fromSeed(
      seedColor: _primaryColor, brightness: Brightness.dark);

  static ThemeData getLightTheme(ColorScheme? lightDynamic) {
    final colorScheme = lightDynamic?.harmonized() ?? _defaultLightColorScheme;
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData getMonetDarkTheme(ColorScheme? darkDynamic) {
    final colorScheme = darkDynamic?.harmonized() ?? _defaultDarkColorScheme;

    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData getBlackDarkTheme(ColorScheme? darkDynamic) {
    final baseScheme = darkDynamic?.harmonized() ?? _defaultDarkColorScheme;
    final colorScheme = baseScheme.copyWith(
      surface: Colors.black,
    );
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 1.5,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
        ),
      ),
      useMaterial3: true,
    );
  }
}

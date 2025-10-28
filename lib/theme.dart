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
    final baseScheme = lightDynamic?.harmonized() ?? _defaultLightColorScheme;
    final colorScheme = baseScheme.copyWith(
      primary: _primaryColor,
      onPrimary: Colors.white,
    );
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 6.0,
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
    final colorScheme = darkDynamic != null
        ? ColorScheme.fromSeed(
            seedColor: darkDynamic.primary,
            brightness: Brightness.dark,
          )
        : _defaultDarkColorScheme;

    final finalScheme = colorScheme.copyWith(
      primary: _primaryColor,
      onPrimary: Colors.white,
    );

    return ThemeData(
      colorScheme: finalScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: finalScheme.primary,
        foregroundColor: finalScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 6.0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: finalScheme.primary,
          foregroundColor: finalScheme.onPrimary,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData getBlackDarkTheme(ColorScheme? darkDynamic) {
    final baseScheme = darkDynamic?.harmonized() ?? _defaultDarkColorScheme;
    final colorScheme = baseScheme.copyWith(
      primary: _primaryColor,
      onPrimary: Colors.white,
      surface: Colors.black,
    );
    return ThemeData(
      colorScheme: colorScheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      cardTheme: const CardThemeData(
        elevation: 6.0,
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

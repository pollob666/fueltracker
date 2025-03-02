import 'package:flutter/material.dart';

class L10n {
  static const all = [
    Locale('en'),
    Locale('bn'),
  ];

  static String getLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'bn':
        return 'বাংলা';
    // Add more cases for other languages
      default:
        return locale.languageCode; // Return locale code as fallback
    }
  }
}
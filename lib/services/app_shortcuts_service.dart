// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

class AppShortcutsService {
  static final AppShortcutsService instance = AppShortcutsService._internal();
  AppShortcutsService._internal();

  final QuickActions _quickActions = const QuickActions();
  bool _initialized = false;

  /// Initializes launcher shortcuts and sets up the tap handler callback.
  void initialize({required void Function(String shortcutType) onShortcut}) {
    if (_initialized) return;
    _initialized = true;

    try {
      _quickActions.initialize((String shortcutType) {
        onShortcut(shortcutType);
      });

      _quickActions.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(
          type: 'action_add_refuel',
          localizedTitle: 'Log Refuel',
          icon: 'ic_shortcut_fuel',
        ),
        const ShortcutItem(
          type: 'action_add_service',
          localizedTitle: 'Log Service',
          icon: 'ic_shortcut_service',
        ),
        const ShortcutItem(
          type: 'action_analytics',
          localizedTitle: 'Analytics',
          icon: 'ic_shortcut_analytics',
        ),
      ]);
    } catch (e) {
      debugPrint('Failed to initialize QuickActions: $e');
    }
  }
}

// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

/// Material 3 Shared Axis PageRoute for smooth, hardware-accelerated transitions.
class SharedAxisPageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SharedAxisTransitionType transitionType;

  SharedAxisPageRoute({
    required this.page,
    this.transitionType = SharedAxisTransitionType.horizontal,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: transitionType,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
        );
}

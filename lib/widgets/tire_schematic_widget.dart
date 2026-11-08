// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/models/tire.dart';
import 'package:fuel_tracker/models/vehicle.dart';
import 'package:fuel_tracker/utils/tire_calculator.dart';

class TireSchematicWidget extends StatelessWidget {
  final Vehicle vehicle;
  final List<Tire> tires;
  final Map<String, Tire> positionMap;
  final String selectedPosition;
  final ValueChanged<String> onPositionSelected;

  const TireSchematicWidget({
    super.key,
    required this.vehicle,
    required this.tires,
    required this.positionMap,
    required this.selectedPosition,
    required this.onPositionSelected,
  });

  bool get _isTwoWheeler =>
      vehicle.type == VehicleType.motorcycle ||
      vehicle.type == VehicleType.scooterOrMoped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isTwoWheeler) {
      return _buildTwoWheelSchematic(context, colorScheme);
    }
    return _buildFourWheelSchematic(context, colorScheme);
  }

  Widget _buildFourWheelSchematic(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 290,
      height: 380,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Front & Rear Axles
          Positioned(
            top: 72,
            child: Container(
              width: 220,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Positioned(
            bottom: 72,
            child: Container(
              width: 220,
              height: 6,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),

          // Vehicle Body Center
          Container(
            width: 140,
            height: 290,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_upward, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'FRONT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  vehicle.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward, size: 14, color: colorScheme.outline),
                      const SizedBox(width: 4),
                      Text(
                        'REAR',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 4 Tire Slots
          _buildTireSlot(context, 'FL', 'Front Left', top: 36, left: 14),
          _buildTireSlot(context, 'FR', 'Front Right', top: 36, right: 14),
          _buildTireSlot(context, 'RL', 'Rear Left', bottom: 36, left: 14),
          _buildTireSlot(context, 'RR', 'Rear Right', bottom: 36, right: 14),
        ],
      ),
    );
  }

  Widget _buildTwoWheelSchematic(BuildContext context, ColorScheme colorScheme) {
    return Container(
      width: 240,
      height: 380,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bike Frame
          Container(
            width: 24,
            height: 220,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          _buildTireSlot(context, 'Front', 'Front Wheel', top: 36),
          _buildTireSlot(context, 'Rear', 'Rear Wheel', bottom: 36),
        ],
      ),
    );
  }

  Widget _buildTireSlot(
    BuildContext context,
    String positionCode,
    String positionLabel, {
    double? top,
    double? bottom,
    double? left,
    double? right,
  }) {
    final tire = positionMap[positionCode];
    final isSelected = selectedPosition == positionCode;
    final depth = tire?.currentTreadDepthMm ?? 0.0;
    final status = tire != null ? TireCalculator.evaluateStatus(depth) : null;
    final statusColor = status?.color ?? const Color(0xFF64748B);

    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: GestureDetector(
        onTap: () => onPositionSelected(positionCode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 54,
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : statusColor,
              width: isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.black)
                    .withValues(alpha: isSelected ? 0.35 : 0.2),
                blurRadius: isSelected ? 8 : 4,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                positionCode,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  tire != null ? '${depth.toStringAsFixed(1)}mm' : '--',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

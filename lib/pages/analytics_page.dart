// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/providers/analytics_providers.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/charts/carbon_footprint_card.dart';
import 'package:fuel_tracker/widgets/charts/condition_impact_bar.dart';
import 'package:fuel_tracker/widgets/charts/price_trend_chart.dart';
import 'package:fuel_tracker/widgets/charts/station_efficiency_scatter.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final vehiclesAsync = ref.watch(vehiclesProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);
    final selectedWindow = ref.watch(selectedTimeWindowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Visual Analytics'),
        elevation: 0,
        actions: [
          vehiclesAsync.maybeWhen(
            data: (vehicles) {
              if (vehicles.isEmpty) return const SizedBox.shrink();
              final currentId = activeVehicle?.id ?? vehicles.first.id;

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: currentId,
                    icon: Icon(Icons.arrow_drop_down, color: colorScheme.onSurface),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    items: vehicles.map((v) {
                      return DropdownMenuItem<int>(
                        value: v.id,
                        child: Text(
                          v.name,
                          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (newId) {
                      if (newId != null) {
                        ref.read(activeVehicleIdProvider.notifier).state = newId;
                      }
                    },
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      drawer: const MyDrawer(),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_car_outlined, size: 48, color: colorScheme.outline),
                  const SizedBox(height: 12),
                  Text('No vehicles found', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text('Add a vehicle to view analytics', style: theme.textTheme.bodyMedium),
                ],
              ),
            );
          }

          final vehicleId = activeVehicle?.id ?? vehicles.first.id!;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Time Window Filter Chips
                    _buildTimeWindowSelector(context, selectedWindow),
                    const SizedBox(height: 16),

                    // Price Trend Chart
                    Consumer(
                      builder: (context, ref, _) {
                        final trends = ref.watch(priceTrendsProvider(vehicleId));
                        final fuelTypes = ref.watch(fuelTypesMapProvider).value ?? {};
                        return PriceTrendChartWidget(
                          priceTrends: trends,
                          fuelTypeMap: fuelTypes,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Station Efficiency Scatter
                    Consumer(
                      builder: (context, ref, _) {
                        final points = ref.watch(stationEfficiencyPointsProvider(vehicleId));
                        final runningAvg = ref.watch(vehicleRunningAverageProvider(vehicleId));
                        return StationEfficiencyScatterWidget(
                          points: points,
                          runningAverage: runningAvg,
                        );
                      },
                    ),
                    const SizedBox(height: 16),

                    // Driving Condition Impact
                    Consumer(
                      builder: (context, ref, _) {
                        final summary = ref.watch(conditionDeltaProvider(vehicleId));
                        return ConditionImpactBarWidget(summary: summary);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Carbon Footprint Card
                    Consumer(
                      builder: (context, ref, _) {
                        final footprint = ref.watch(carbonFootprintProvider(vehicleId));
                        return CarbonFootprintCardWidget(result: footprint);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              const BannerAdWidget(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeWindowSelector(BuildContext context, AnalyticsTimeWindow current) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(context, '1 Month', AnalyticsTimeWindow.oneMonth, current),
          const SizedBox(width: 8),
          _buildChip(context, '3 Months', AnalyticsTimeWindow.threeMonths, current),
          const SizedBox(width: 8),
          _buildChip(context, '6 Months', AnalyticsTimeWindow.sixMonths, current),
          const SizedBox(width: 8),
          _buildChip(context, '1 Year', AnalyticsTimeWindow.oneYear, current),
          const SizedBox(width: 8),
          _buildChip(context, 'All Time', AnalyticsTimeWindow.allTime, current),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context,
    String label,
    AnalyticsTimeWindow target,
    AnalyticsTimeWindow current,
  ) {
    final isSelected = target == current;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(selectedTimeWindowProvider.notifier).state = target;
        }
      },
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
    );
  }
}

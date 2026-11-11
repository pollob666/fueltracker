// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fuel_tracker/models/fuel_record.dart';
import 'package:fuel_tracker/pages/add_data_page.dart';
import 'package:fuel_tracker/providers/analytics_providers.dart';
import 'package:fuel_tracker/providers/fuel_record_providers.dart';
import 'package:fuel_tracker/providers/non_fuel_expense_providers.dart';
import 'package:fuel_tracker/providers/vehicle_providers.dart';
import 'package:fuel_tracker/services/analytics_service.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/utils/long_screenshot_service.dart';
import 'package:fuel_tracker/widgets/add_expense_bottom_sheet.dart';
import 'package:fuel_tracker/widgets/banner_ad_widget.dart';
import 'package:fuel_tracker/widgets/charts/carbon_footprint_card.dart';
import 'package:fuel_tracker/widgets/charts/condition_impact_bar.dart';
import 'package:fuel_tracker/widgets/charts/price_trend_chart.dart';
import 'package:fuel_tracker/widgets/charts/station_efficiency_scatter.dart';
import 'package:fuel_tracker/widgets/charts/tco_stacked_bar_chart.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';
import 'package:intl/intl.dart';

class AnalyticsPage extends ConsumerStatefulWidget {
  const AnalyticsPage({super.key});

  @override
  ConsumerState<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends ConsumerState<AnalyticsPage> {
  final GlobalKey _screenshotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final vehiclesAsync = ref.watch(vehiclesProvider);
    final activeVehicle = ref.watch(activeVehicleProvider);
    final selectedWindow = ref.watch(selectedTimeWindowProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 8,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Visual Analytics'),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.screenshot_outlined),
            tooltip: 'Long Screenshot',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final messenger = ScaffoldMessenger.of(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Capturing screenshot...'),
                  duration: Duration(milliseconds: 700),
                ),
              );
              final success = await LongScreenshotService.captureAndShare(
                context: context,
                boundaryKey: _screenshotKey,
                fileNamePrefix: 'fueltracker_analytics',
                shareText: 'Fuel Tracker Visual Analytics - ${activeVehicle?.name ?? ""}',
              );
              if (!success && mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to capture screenshot')),
                );
              }
            },
          ),
          vehiclesAsync.maybeWhen(
            data: (vehicles) {
              if (vehicles.isEmpty) return const SizedBox.shrink();
              final currentId = activeVehicle?.id ?? vehicles.first.id;

              return Container(
                margin: const EdgeInsets.only(right: 12.0),
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.onPrimary.withValues(alpha: 0.25),
                    width: 1,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: currentId,
                    isDense: true,
                    icon: Icon(Icons.arrow_drop_down, color: colorScheme.onPrimary, size: 20),
                    dropdownColor: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    selectedItemBuilder: (context) {
                      return vehicles.map((v) {
                        return ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 88),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              v.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }).toList();
                    },
                    items: vehicles.map((v) {
                      final isSelected = v.id == currentId;
                      return DropdownMenuItem<int>(
                        value: v.id,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.directions_car_outlined,
                              size: 18,
                              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                v.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: RepaintBoundary(
                    key: _screenshotKey,
                    child: ColoredBox(
                      color: theme.scaffoldBackgroundColor,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Time Window Filter Chips
                          _buildTimeWindowSelector(context, selectedWindow),
                          const SizedBox(height: 16),

                          // Total Cost of Ownership (TCO) Stacked Bar Chart
                          Consumer(
                            builder: (context, ref, _) {
                              final summary = ref.watch(tcoOverviewProvider(vehicleId));
                              final currSym = activeVehicle?.baseCurrency ?? AppSettings.defaultBaseCurrency;
                              final distSym = activeVehicle?.distanceUnit.symbol ?? 'km';
                              return TcoStackedBarWidget(
                                summary: summary,
                                currencySymbol: currSym,
                                distanceUnit: distSym,
                                onLogExpense: () {
                                  AddExpenseBottomSheet.show(context, vehicleId: vehicleId);
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Price Trend Chart
                          Consumer(
                            builder: (context, ref, _) {
                              final trends = ref.watch(priceTrendsProvider(vehicleId));
                              final fuelTypes = ref.watch(fuelTypesMapProvider).value ?? {};
                              final currSym = activeVehicle?.baseCurrency ?? AppSettings.defaultBaseCurrency;
                              final volSym = activeVehicle?.fuelVolumeUnit.symbol ?? 'L';
                              return PriceTrendChartWidget(
                                priceTrends: trends,
                                fuelTypeMap: fuelTypes,
                                currencySymbol: currSym,
                                volumeUnit: volSym,
                                onRecordTap: (record) => _handleRecordTap(context, record),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Station Efficiency Scatter
                          Consumer(
                            builder: (context, ref, _) {
                              final points = ref.watch(stationEfficiencyPointsProvider(vehicleId));
                              final runningAvg = ref.watch(vehicleRunningAverageProvider(vehicleId));
                              final econUnit = activeVehicle?.consumptionUnit.symbol ?? 'km/L';
                              return StationEfficiencyScatterWidget(
                                points: points,
                                runningAverage: runningAvg,
                                economyUnit: econUnit,
                                onRecordTap: (record) => _handleRecordTap(context, record),
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Driving Condition Impact
                          Consumer(
                            builder: (context, ref, _) {
                              final summary = ref.watch(conditionDeltaProvider(vehicleId));
                              final econUnit = activeVehicle?.consumptionUnit.symbol ?? 'km/L';
                              final currSym = activeVehicle?.baseCurrency ?? AppSettings.defaultBaseCurrency;
                              final distSym = activeVehicle?.distanceUnit.symbol ?? 'km';
                              return ConditionImpactBarWidget(
                                summary: summary,
                                economyUnit: econUnit,
                                currencySymbol: currSym,
                                distanceUnit: distSym,
                              );
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
                  ),
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
    final customRange = ref.watch(customAnalyticsDateRangeProvider);
    String customLabel = 'Custom Range';
    if (customRange != null) {
      customLabel = '${DateFormat('dd MMM').format(customRange.start)} - ${DateFormat('dd MMM').format(customRange.end)}';
    }

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
          const SizedBox(width: 8),
          _buildCustomChip(context, customLabel, current, customRange),
        ],
      ),
    );
  }

  Widget _buildCustomChip(
    BuildContext context,
    String label,
    AnalyticsTimeWindow current,
    DateTimeRange? customRange,
  ) {
    final isSelected = current == AnalyticsTimeWindow.custom;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ActionChip(
      avatar: Icon(
        Icons.date_range,
        size: 16,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      backgroundColor: isSelected ? colorScheme.primaryContainer : null,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
      ),
      onPressed: () async {
        final now = DateTime.now();
        final initialRange = customRange ??
            DateTimeRange(
              start: DateTime(now.year, now.month - 1, now.day),
              end: now,
            );
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          initialDateRange: initialRange,
        );
        if (picked != null) {
          ref.read(customAnalyticsDateRangeProvider.notifier).state = picked;
          ref.read(selectedTimeWindowProvider.notifier).state = AnalyticsTimeWindow.custom;
        }
      },
    );
  }

  void _handleRecordTap(BuildContext context, FuelRecord record) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeVehicle = ref.read(activeVehicleProvider);
    final currencySymbol = activeVehicle?.baseCurrency ?? AppSettings.defaultBaseCurrency;
    final volumeUnitStr = activeVehicle?.fuelVolumeUnit.symbol ?? 'L';
    final distUnitStr = activeVehicle?.distanceUnit.symbol ?? 'km';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Refuel Record #${record.id ?? ""}',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(record.date),
                      style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMetricColumn(theme, 'Volume', '${record.volume.toStringAsFixed(1)} $volumeUnitStr'),
                      _buildMetricColumn(theme, 'Rate', '$currencySymbol${record.rate.toStringAsFixed(2)}/$volumeUnitStr'),
                      _buildMetricColumn(theme, 'Paid', '$currencySymbol${record.paidAmount.toStringAsFixed(2)}', isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.speed, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Odometer: ${record.odometer.toStringAsFixed(0)} $distUnitStr', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Icon(Icons.alt_route, size: 16, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text('Condition: ${record.drivingCondition.name.toUpperCase()}', style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AddDataPage(recordToEdit: record),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit This Refuel Record'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricColumn(ThemeData theme, String label, String value, {bool isBold = false}) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? theme.colorScheme.primary : null,
          ),
        ),
      ],
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

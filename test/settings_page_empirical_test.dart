// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/pages/settings_page.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSettingsApp({
    Locale locale = const Locale('en'),
    Size surfaceSize = const Size(800, 1200),
  }) {
    return ProviderScope(
      child: MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          home: const SettingsPage(),
        ),
      ),
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'maxVolume': 50.0,
      'storageOption': 'Local',
      'localFolderPath': '/storage/emulated/0/FuelTracker',
      'googleDriveFolderPath': 'My Drive/FuelTracker',
      'dropboxFolderPath': '',
      'language': 'en',
      'themeMode': 'system',
      'darkTheme': 'monet',
      'defaultFuelPrices': '{}',
    });
    AppSettings.maxVolume = 50.0;
    AppSettings.storageOption = 'Local';
    AppSettings.localFolderPath = '/storage/emulated/0/FuelTracker';
    AppSettings.googleDriveFolderPath = 'My Drive/FuelTracker';
    AppSettings.dropboxFolderPath = '';
    AppSettings.language = 'en';
    AppSettings.themeMode = 'system';
    AppSettings.darkTheme = 'monet';
    AppSettings.defaultFuelPrices = {};
  });

  group('SettingsPage Empirical Adversarial Challenges', () {
    testWidgets(
        'Challenge 1: Input Layout & Constraints (Row MainAxisSize.min in suffixIcon under narrow width constraints)',
        (WidgetTester tester) async {
      // Stress test on very narrow viewport (e.g. 300px width)
      await tester.binding.setSurfaceSize(const Size(300, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildSettingsApp(surfaceSize: const Size(300, 800)));
      await tester.pumpAndSettle();

      // Ensure no layout exceptions or overflow happened
      expect(tester.takeException(), isNull);

      final folderFieldFinder = find.widgetWithText(TextFormField, 'Folder Path');
      expect(folderFieldFinder, findsOneWidget);

      final rowFinder = find.descendant(
        of: folderFieldFinder,
        matching: find.byType(Row),
      );
      expect(rowFinder, findsOneWidget);
      final Row row = tester.widget(rowFinder);
      expect(
        row.mainAxisSize,
        equals(MainAxisSize.min),
        reason: 'SuffixIcon Row must use MainAxisSize.min to prevent unbounded width layout overflow',
      );

      // Verify both icons fit in suffixIcon without overflowing RenderFlex
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets(
        'Challenge 2: Clear Button State lifecycle and reactivity',
        (WidgetTester tester) async {
      // 1. Initialized with non-empty path -> Clear icon is present
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      expect(find.text('/storage/emulated/0/FuelTracker'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);

      // 2. Tap clear button -> _folderController.clear() and setState() executed
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // 3. Clear button must be removed from the widget tree
      expect(find.byIcon(Icons.clear), findsNothing);
      // 4. Folder open button remains visible
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
      // 5. Text is now empty
      expect(find.text('/storage/emulated/0/FuelTracker'), findsNothing);

      // Verify no exception occurred during clearing and state rebuild
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Challenge 3: Clear Button does not display when initial path is empty',
        (WidgetTester tester) async {
      AppSettings.localFolderPath = '';
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      // Clear icon must be absent
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);
    });

    testWidgets(
        'Challenge 4: Storage Option Persistence - Clearing path persists empty string to AppSettings & SharedPreferences',
        (WidgetTester tester) async {
      AppSettings.localFolderPath = '/storage/emulated/0/FuelTracker';
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      // Verify initial setup
      expect(AppSettings.localFolderPath, equals('/storage/emulated/0/FuelTracker'));
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      // Scroll to and tap Save Settings button
      final saveButton = find.widgetWithText(ElevatedButton, 'Save Settings');
      expect(saveButton, findsOneWidget);
      await tester.ensureVisible(saveButton);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();

      // Verify in-memory AppSettings.localFolderPath is empty
      expect(
        AppSettings.localFolderPath,
        equals(''),
        reason: 'Local folder path must be persisted as empty string to enable downstream scoped storage share',
      );

      // Verify SharedPreferences persisted empty string
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('localFolderPath'), equals(''));

      // Verify SnackBar was shown for user confirmation
      final context = tester.element(find.byType(SettingsPage));
      final loc = AppLocalizations.of(context)!;
      expect(find.text(loc.settingsSaved), findsOneWidget);
    });

    testWidgets(
        'Challenge 5: Helper text rendering in English and Bengali',
        (WidgetTester tester) async {
      // English check
      await tester.pumpWidget(buildSettingsApp(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(
        find.text('Optional. Leave empty to share via system share sheet.'),
        findsOneWidget,
      );

      // Bengali check
      await tester.pumpWidget(buildSettingsApp(locale: const Locale('bn')));
      await tester.pumpAndSettle();

      expect(
        find.text('ঐচ্ছিক। সিস্টেম শেয়ার শীট ব্যবহার করতে খালি রাখুন।'),
        findsOneWidget,
      );
    });

    testWidgets(
        'Challenge 6: Switching storage options updates folder controller and clear button presence',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSettingsApp());
      await tester.pumpAndSettle();

      // Initial: Local -> non-empty ('/storage/emulated/0/FuelTracker') -> Clear button visible
      expect(find.text('/storage/emulated/0/FuelTracker'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Switch to Dropbox (which was initialized to empty '')
      final storageDropdown = find.byType(DropdownButtonFormField<String>);
      expect(storageDropdown, findsOneWidget);
      await tester.tap(storageDropdown);
      await tester.pumpAndSettle();

      final dropboxOption = find.text('Dropbox').last;
      await tester.tap(dropboxOption);
      await tester.pumpAndSettle();

      // Now Dropbox has empty path, so clear button should be gone
      expect(find.byIcon(Icons.clear), findsNothing);
      expect(find.byIcon(Icons.folder_open), findsOneWidget);

      // Switch back to Google Drive (which has 'My Drive/FuelTracker')
      await tester.tap(storageDropdown);
      await tester.pumpAndSettle();

      final gdriveOption = find.text('Google Drive').last;
      await tester.tap(gdriveOption);
      await tester.pumpAndSettle();

      // Now Google Drive is non-empty, so clear button should be visible again
      expect(find.text('My Drive/FuelTracker'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });
  });
}


// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/pages/add_data_page.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/pages/all_data_page.dart';
import 'package:fuel_tracker/pages/import_page.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:fuel_tracker/pages/manage_vehicles_page.dart';
import 'package:fuel_tracker/pages/settings_page.dart';

class MyDrawer extends StatefulWidget {
  const MyDrawer({super.key});

  @override
  State<MyDrawer> createState() => _MyDrawerState();
}

class _MyDrawerState extends State<MyDrawer> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF22484e)
                  : colorScheme.primary,
            ),
            child: Row(
              children: [
                Image.asset(
                  'assets/dash.png',
                  height: 60,
                  width: 60,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.appTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: Text(AppLocalizations.of(context)!.dashboard),
            selected: _selectedIndex == 0,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(0);
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.add_circle_outline),
            title: Text(AppLocalizations.of(context)!.addFuelData),
            selected: _selectedIndex == 6,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(6);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AddDataPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: Text(AppLocalizations.of(context)!.allData),
            selected: _selectedIndex == 1,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(1);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AllDataPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: Text(AppLocalizations.of(context)!.manageVehicles),
            selected: _selectedIndex == 2,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(2);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const ManageVehiclesPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: Text(AppLocalizations.of(context)!.import),
            selected: _selectedIndex == 3,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(3);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ImportPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(AppLocalizations.of(context)!.export),
            selected: _selectedIndex == 4,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(4);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ExportPage()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: Text(AppLocalizations.of(context)!.settings),
            selected: _selectedIndex == 5,
            selectedTileColor: colorScheme.primary.withOpacity(0.1),
            selectedColor: colorScheme.primary,
            onTap: () {
              _onItemTapped(5);
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          ),
        ],
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}

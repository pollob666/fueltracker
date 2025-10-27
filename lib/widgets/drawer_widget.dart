// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2024 Andalib Bin Haque <pollob666@gmail.com>

import 'package:flutter/material.dart';
import 'package:fuel_tracker/l10n/l10n.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/pages/all_data_page.dart';
import 'package:fuel_tracker/pages/import_page.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:fuel_tracker/pages/manage_vehicles_page.dart';
import 'package:fuel_tracker/pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(child: Text(AppLocalizations.of(context).appTitle, style: const TextStyle(fontSize: 24))),
          ListTile(
            title: Text(AppLocalizations.of(context).dashboard),
            onTap: () {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const DashboardPage()));
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).allData),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const AllDataPage()));
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).manageVehicles),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ManageVehiclesPage()));
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).import),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ImportPage()));
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).export),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const ExportPage()));
            },
          ),
          ListTile(
            title: Text(AppLocalizations.of(context).settings),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => const SettingsPage()));
            },
          ),
        ],
      ),
    );
  }
}

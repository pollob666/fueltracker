import 'package:flutter/material.dart';
import 'package:fuel_tracker/pages/dashboard_page.dart';
import 'package:fuel_tracker/pages/all_data_page.dart';
import 'package:fuel_tracker/pages/import_page.dart';
import 'package:fuel_tracker/pages/export_page.dart';
import 'package:fuel_tracker/pages/settings_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(child: Text("Menu", style: TextStyle(fontSize: 24))),
          ListTile(
            title: Text("Dashboard"),
            onTap: () {
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => DashboardPage()));
            },
          ),
          ListTile(
            title: Text("All Data"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => AllDataPage()));
            },
          ),
          ListTile(
            title: Text("Import"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ImportPage()));
            },
          ),
          ListTile(
            title: Text("Export"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ExportPage()));
            },
          ),
          ListTile(
            title: Text("Settings"),
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (context) => SettingsPage()));
            },
          ),
        ],
      ),
    );
  }
}

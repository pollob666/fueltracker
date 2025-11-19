
import 'package:flutter/material.dart';

class AppDrawer extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    final headerColor = isDarkMode
        ? const Color(0xFF22484e)
        : theme.colorScheme.primary;

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(
              color: headerColor,
            ),
            child: Row(
              children: <Widget>[
                Image.asset(
                  'assets/dash.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Fuel Consumption Tracker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            selected: widget.selectedIndex == 0,
            onTap: () => widget.onItemTapped(0),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.list_alt),
            title: const Text('All Data'),
            selected: widget.selectedIndex == 1,
            onTap: () => widget.onItemTapped(1),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.directions_car),
            title: const Text('Manage Vehicles'),
            selected: widget.selectedIndex == 2,
            onTap: () => widget.onItemTapped(2),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Import Data'),
            selected: widget.selectedIndex == 3,
            onTap: () => widget.onItemTapped(3),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Export Data'),
            selected: widget.selectedIndex == 4,
            onTap: () => widget.onItemTapped(4),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            selected: widget.selectedIndex == 5,
            onTap: () => widget.onItemTapped(5),
            selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
            selectedColor: theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

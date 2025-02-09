import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fuel_tracker/utils/app_settings.dart';
import 'package:fuel_tracker/widgets/drawer_widget.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController _maxVolumeController = TextEditingController();
  String _storageOption = AppSettings.storageOption;
  TextEditingController _folderController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _maxVolumeController.text = AppSettings.maxVolume.toString();
    _folderController.text = _getCurrentFolderPath();
  }

  String _getCurrentFolderPath() {
    if (_storageOption == 'Local') return AppSettings.localFolderPath;
    if (_storageOption == 'Google Drive')
      return AppSettings.googleDriveFolderPath;
    if (_storageOption == 'Dropbox') return AppSettings.dropboxFolderPath;
    return '';
  }

  Future<void> _pickFolder() async {
    // Use FilePicker to let the user select a directory.
    String? selectedDirectory =
    await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _folderController.text = selectedDirectory;
      });
    }
  }

  @override
  void dispose() {
    _maxVolumeController.dispose();
    _folderController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      AppSettings.maxVolume = double.parse(_maxVolumeController.text);
      AppSettings.storageOption = _storageOption;
      if (_storageOption == 'Local') {
        AppSettings.localFolderPath = _folderController.text;
      } else if (_storageOption == 'Google Drive') {
        AppSettings.googleDriveFolderPath = _folderController.text;
      } else if (_storageOption == 'Dropbox') {
        AppSettings.dropboxFolderPath = _folderController.text;
      }
      await AppSettings.saveSettings();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Settings saved.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _maxVolumeController,
                decoration: InputDecoration(
                    labelText: "Maximum Tank Capacity (litres)"),
                keyboardType:
                TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Enter maximum capacity";
                  return null;
                },
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _storageOption,
                items: ["Local", "Google Drive", "Dropbox"]
                    .map((option) => DropdownMenuItem(
                  value: option,
                  child: Text(option),
                ))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _storageOption = val!;
                    _folderController.text = _getCurrentFolderPath();
                  });
                },
                decoration: InputDecoration(labelText: "File Storage Option"),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: _folderController,
                decoration: InputDecoration(
                  labelText: "Folder Path",
                  suffixIcon: IconButton(
                      icon: Icon(Icons.folder_open),
                      onPressed: _pickFolder),
                ),
                readOnly: true,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveSettings,
                child: Text("Save Settings"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

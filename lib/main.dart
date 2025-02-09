import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// -------------------------------------------
/// DATA MODEL: FuelRecord
/// -------------------------------------------
class FuelRecord {
  int? id;
  DateTime date;
  double odometer;
  String fuelType;
  double rate;
  double volume;
  double paidAmount;

  FuelRecord({
    this.id,
    required this.date,
    required this.odometer,
    required this.fuelType,
    required this.rate,
    required this.volume,
    required this.paidAmount,
  });

  Map<String, dynamic> toMap() {
    var map = <String, dynamic>{
      'date': date.toIso8601String(),
      'odometer': odometer,
      'fuelType': fuelType,
      'rate': rate,
      'volume': volume,
      'paidAmount': paidAmount,
    };
    if (id != null) map['id'] = id;
    return map;
  }

  factory FuelRecord.fromMap(Map<String, dynamic> map) {
    return FuelRecord(
      id: map['id'],
      date: DateTime.parse(map['date']),
      odometer: map['odometer'],
      fuelType: map['fuelType'],
      rate: map['rate'],
      volume: map['volume'],
      paidAmount: map['paidAmount'],
    );
  }
}

/// -------------------------------------------
/// DATABASE HELPER: Using sqflite
/// -------------------------------------------
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, "fuel_tracker.db");
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE fuel_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        odometer REAL NOT NULL,
        fuelType TEXT NOT NULL,
        rate REAL NOT NULL,
        volume REAL NOT NULL,
        paidAmount REAL NOT NULL
      )
    ''');
  }

  Future<int> insertFuelRecord(FuelRecord record) async {
    Database db = await instance.database;
    return await db.insert('fuel_records', record.toMap());
  }

  Future<List<FuelRecord>> getFuelRecords() async {
    Database db = await instance.database;
    var records = await db.query('fuel_records', orderBy: 'date ASC');
    return records.isNotEmpty
        ? records.map((e) => FuelRecord.fromMap(e)).toList()
        : [];
  }

  Future<int> deleteFuelRecord(int id) async {
    Database db = await instance.database;
    return await db.delete('fuel_records', where: 'id = ?', whereArgs: [id]);
  }
}

/// -------------------------------------------
/// APP SETTINGS: Using SharedPreferences
/// -------------------------------------------
class AppSettings {
  static double maxVolume = 100.0;
  static String storageOption = 'Local'; // Options: Local, Google Drive, Dropbox
  static String localFolderPath = '';
  static String googleDriveFolderPath = '';
  static String dropboxFolderPath = '';

  static Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    maxVolume = prefs.getDouble('maxVolume') ?? 100.0;
    storageOption = prefs.getString('storageOption') ?? 'Local';
    localFolderPath = prefs.getString('localFolderPath') ?? '';
    googleDriveFolderPath = prefs.getString('googleDriveFolderPath') ?? '';
    dropboxFolderPath = prefs.getString('dropboxFolderPath') ?? '';
  }

  static Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('maxVolume', maxVolume);
    await prefs.setString('storageOption', storageOption);
    await prefs.setString('localFolderPath', localFolderPath);
    await prefs.setString('googleDriveFolderPath', googleDriveFolderPath);
    await prefs.setString('dropboxFolderPath', dropboxFolderPath);
  }
}

/// -------------------------------------------
/// MAIN FUNCTION
/// -------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.loadSettings();
  runApp(MyApp());
}

/// -------------------------------------------
/// MyApp: Root Widget
/// -------------------------------------------
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Fuel Consumption Tracker",
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DashboardPage(),
    );
  }
}

/// -------------------------------------------
/// DashboardPage: Home Screen with stats
/// -------------------------------------------
class DashboardPage extends StatefulWidget {
  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<FuelRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    var recs = await DatabaseHelper.instance.getFuelRecords();
    setState(() {
      records = recs;
    });
  }

  @override
  Widget build(BuildContext context) {
    double lastMileage = 0;
    double runningAverage = 0;
    if (records.length >= 2) {
      List<double> mileages = [];
      for (int i = 1; i < records.length; i++) {
        double diff = records[i].odometer - records[i - 1].odometer;
        double mileage = diff / records[i].volume;
        mileages.add(mileage);
      }
      lastMileage = mileages.last;
      runningAverage = mileages.reduce((a, b) => a + b) / mileages.length;
    }

    double lastRefuelVolume = records.isNotEmpty ? records.last.volume : 0;

    return Scaffold(
      appBar: AppBar(title: Text("Fuel Consumption Tracker")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Two side-by-side cards: running average and last mileage
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Running Average Mileage"),
                          SizedBox(height: 8),
                          Text(
                            runningAverage.toStringAsFixed(2) + " km/l",
                            style: TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("Last Time Mileage"),
                          SizedBox(height: 8),
                          Text(
                            lastMileage.toStringAsFixed(2) + " km/l",
                            style: TextStyle(fontSize: 24),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // Card showing last refuel volume
            Card(
              child: ListTile(
                title: Text("Last Refuel Volume"),
                subtitle: Text(lastRefuelVolume.toStringAsFixed(2) + " litres"),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddDataPage()));
                _loadRecords(); // Refresh after adding new record.
              },
              child: Text("Add New Data"),
            ),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// Drawer Widget (Sidebar)
/// -------------------------------------------
class MyDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        children: [
          DrawerHeader(child: Text("Menu", style: TextStyle(fontSize: 24))),
          ListTile(
            title: Text("Dashboard"),
            onTap: () {
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (context) => DashboardPage()));
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

/// -------------------------------------------
/// AddDataPage: Form to add a new fuel record
/// -------------------------------------------
class AddDataPage extends StatefulWidget {
  @override
  _AddDataPageState createState() => _AddDataPageState();
}

class _AddDataPageState extends State<AddDataPage> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  TextEditingController _odometerController = TextEditingController();
  String _selectedFuelType = "Octane";
  TextEditingController _rateController = TextEditingController();
  double _volume = 0;
  TextEditingController _volumeController = TextEditingController();
  TextEditingController _paidAmountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _volumeController.text = _volume.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _rateController.dispose();
    _volumeController.dispose();
    _paidAmountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      TimeOfDay? time = await showTimePicker(
          context: context, initialTime: TimeOfDay.fromDateTime(_selectedDate));
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
              picked.year, picked.month, picked.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxVolume = AppSettings.maxVolume; // Maximum from settings

    return Scaffold(
      appBar: AppBar(title: Text("Add Fuel Data")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Date and time picker
                Row(
                  children: [
                    Expanded(
                      child: Text("Date & Time: " +
                          _selectedDate.toLocal().toString().substring(0, 16)),
                    ),
                    IconButton(
                      icon: Icon(Icons.calendar_today),
                      onPressed: _pickDate,
                    ),
                  ],
                ),
                TextFormField(
                  controller: _odometerController,
                  decoration:
                  InputDecoration(labelText: "Odometer Reading (km)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Enter odometer reading";
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  value: _selectedFuelType,
                  items: ["Octane", "Petrol"]
                      .map((fuel) => DropdownMenuItem(
                    value: fuel,
                    child: Text(fuel),
                  ))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedFuelType = val!;
                    });
                  },
                  decoration: InputDecoration(labelText: "Fuel Type"),
                ),
                TextFormField(
                  controller: _rateController,
                  decoration:
                  InputDecoration(labelText: "Fuel Price Rate (BDT)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Enter fuel price rate";
                    return null;
                  },
                ),
                SizedBox(height: 16),
                // Volume slider and input field
                Text("Total Volume (litres): " +
                    _volume.toStringAsFixed(2)),
                Slider(
                  value: _volume,
                  min: 0,
                  max: maxVolume,
                  divisions: (maxVolume * 100).toInt(),
                  label: _volume.toStringAsFixed(2),
                  onChanged: (val) {
                    setState(() {
                      _volume = double.parse(val.toStringAsFixed(2));
                      _volumeController.text = _volume.toStringAsFixed(2);
                    });
                  },
                ),
                TextFormField(
                  controller: _volumeController,
                  decoration:
                  InputDecoration(labelText: "Total Volume (litres)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  onChanged: (val) {
                    double? parsed = double.tryParse(val);
                    if (parsed != null) {
                      setState(() {
                        _volume = parsed;
                      });
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Enter total volume";
                    return null;
                  },
                ),
                TextFormField(
                  controller: _paidAmountController,
                  decoration:
                  InputDecoration(labelText: "Paid Amount (BDT)"),
                  keyboardType:
                  TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return "Enter paid amount";
                    return null;
                  },
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Create a new FuelRecord and save it.
                      FuelRecord record = FuelRecord(
                        date: _selectedDate,
                        odometer: double.parse(_odometerController.text),
                        fuelType: _selectedFuelType,
                        rate: double.parse(_rateController.text),
                        volume: _volume,
                        paidAmount: double.parse(_paidAmountController.text),
                      );
                      await DatabaseHelper.instance.insertFuelRecord(record);
                      Navigator.pop(context);
                    }
                  },
                  child: Text("Save"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// AllDataPage: Show all records in a table
/// -------------------------------------------
class AllDataPage extends StatefulWidget {
  @override
  _AllDataPageState createState() => _AllDataPageState();
}

class _AllDataPageState extends State<AllDataPage> {
  List<FuelRecord> records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    List<FuelRecord> recs = await DatabaseHelper.instance.getFuelRecords();
    setState(() {
      records = recs;
    });
  }

  // Color rows based on paid amount vs. expected (volume * rate)
  Color getRowColor(FuelRecord record) {
    double expected = record.volume * record.rate;
    if (record.paidAmount < expected) return Colors.green[200]!;
    if (record.paidAmount > expected) return Colors.pink[200]!;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("All Data")),
      drawer: MyDrawer(),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: [
            DataColumn(label: Text("Date")),
            DataColumn(label: Text("Odometer")),
            DataColumn(label: Text("Fuel Type")),
            DataColumn(label: Text("Rate")),
            DataColumn(label: Text("Volume")),
            DataColumn(label: Text("Paid Amount")),
          ],
          rows: records
              .map(
                (record) => DataRow(
              color: MaterialStateProperty.resolveWith<Color?>(
                      (states) => getRowColor(record)),
              cells: [
                DataCell(Text(record.date
                    .toLocal()
                    .toString()
                    .substring(0, 16))),
                DataCell(Text(record.odometer.toStringAsFixed(2))),
                DataCell(Text(record.fuelType)),
                DataCell(Text(record.rate.toStringAsFixed(2))),
                DataCell(Text(record.volume.toStringAsFixed(2))),
                DataCell(Text(record.paidAmount.toStringAsFixed(2))),
              ],
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// SettingsPage: Configure maximum capacity and file storage options
/// -------------------------------------------
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
    if (_storageOption == 'Google Drive') return AppSettings.googleDriveFolderPath;
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

/// -------------------------------------------
/// ExportPage: Export all data as CSV to the chosen folder
/// -------------------------------------------
class ExportPage extends StatefulWidget {
  @override
  _ExportPageState createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  bool _exporting = false;
  String _message = "";

  Future<void> _exportData() async {
    setState(() {
      _exporting = true;
      _message = "";
    });
    List<FuelRecord> records =
    await DatabaseHelper.instance.getFuelRecords();
    // Create CSV data
    List<List<String>> csvData = [
      ["Date", "Odometer", "Fuel Type", "Rate", "Volume", "Paid Amount"],
      ...records.map((r) => [
        r.date.toIso8601String(),
        r.odometer.toStringAsFixed(2),
        r.fuelType,
        r.rate.toStringAsFixed(2),
        r.volume.toStringAsFixed(2),
        r.paidAmount.toStringAsFixed(2),
      ])
    ];

    String csv = const ListToCsvConverter().convert(csvData);

    // Get folder path based on current settings.
    String folderPath = "";
    if (AppSettings.storageOption == 'Local') {
      folderPath = AppSettings.localFolderPath;
    } else if (AppSettings.storageOption == 'Google Drive') {
      folderPath = AppSettings.googleDriveFolderPath;
    } else if (AppSettings.storageOption == 'Dropbox') {
      folderPath = AppSettings.dropboxFolderPath;
    }

    if (folderPath.isEmpty) {
      setState(() {
        _exporting = false;
        _message = "Folder path not set in settings.";
      });
      return;
    }

    // Create a file name with timestamp.
    String fileName =
        "fuel_data_${DateTime.now().millisecondsSinceEpoch}.csv";
    File file = File("$folderPath/$fileName");
    try {
      await file.writeAsString(csv);
      setState(() {
        _exporting = false;
        _message = "Data exported to $fileName";
      });
    } catch (e) {
      setState(() {
        _exporting = false;
        _message = "Failed to export: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Export Data")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _exporting ? null : _exportData,
              child: Text("Export to CSV"),
            ),
            SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}

/// -------------------------------------------
/// ImportPage: Import data from a CSV file
/// -------------------------------------------
class ImportPage extends StatefulWidget {
  @override
  _ImportPageState createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  bool _importing = false;
  String _message = "";

  Future<void> _importData() async {
    setState(() {
      _importing = true;
      _message = "";
    });
    // Let the user pick a CSV file.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      String content = await file.readAsString();
      List<List<dynamic>> csvTable =
      const CsvToListConverter().convert(content);
      if (csvTable.length < 2) {
        setState(() {
          _importing = false;
          _message = "No data found in CSV.";
        });
        return;
      }
      // Remove header row.
      csvTable.removeAt(0);
      // Insert each row as a FuelRecord.
      for (var row in csvTable) {
        try {
          FuelRecord record = FuelRecord(
            date: DateTime.parse(row[0].toString()),
            odometer: double.parse(row[1].toString()),
            fuelType: row[2].toString(),
            rate: double.parse(row[3].toString()),
            volume: double.parse(row[4].toString()),
            paidAmount: double.parse(row[5].toString()),
          );
          await DatabaseHelper.instance.insertFuelRecord(record);
        } catch (e) {
          // You might want to handle or log errors for each row.
        }
      }
      setState(() {
        _importing = false;
        _message = "Data imported successfully.";
      });
    } else {
      setState(() {
        _importing = false;
        _message = "File selection canceled.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Import Data")),
      drawer: MyDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: _importing ? null : _importData,
              child: Text("Import CSV"),
            ),
            SizedBox(height: 16),
            Text(_message),
          ],
        ),
      ),
    );
  }
}

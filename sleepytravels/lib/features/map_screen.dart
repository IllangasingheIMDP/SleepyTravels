import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/repositories/alarm_repository.dart';
import '../data/models/alarm_model.dart';
import 'alarm_list_screen.dart';
import 'logs_screen.dart';
import 'package:file_picker/file_picker.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? selectedLocation;
  final AlarmRepository _repo = AlarmRepository();
  int radius = 2000;
  String? mp3Path;

  Future<void> pickMP3() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => mp3Path = result.files.single.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("SleepyTravels"),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmListScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LogsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(6.9271, 79.8612),
                initialZoom: 13,
                onTap: (tapPosition, point) {
                  setState(() => selectedLocation = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: 'com.example.sleepytravels_app',
                ),
                if (selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation!,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (selectedLocation != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text("Radius (m): "),
                      Expanded(
                        child: Slider(
                          value: radius.toDouble(),
                          min: 500,
                          max: 5000,
                          divisions: 9,
                          label: "$radius m",
                          onChanged: (v) => setState(() => radius = v.toInt()),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton(
                        onPressed: pickMP3,
                        child: Text(
                          mp3Path == null ? "Pick MP3" : "MP3 Selected",
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final alarm = AlarmModel(
                            destLat: selectedLocation!.latitude,
                            destLng: selectedLocation!.longitude,
                            radiusM: radius,
                            soundPath: mp3Path,
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                          );
                          await _repo.addAlarm(alarm);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Alarm saved!")),
                          );
                        },
                        child: const Text("Save Alarm"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

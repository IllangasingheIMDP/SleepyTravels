import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../data/repositories/alarm_repository.dart';
import '../widgets/edit_alarm_dialog.dart';
import 'map_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen> {
  final AlarmRepository _repo = AlarmRepository();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Alarms")),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, child) {
          final alarms = _repo.items;
          if (alarms.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.alarm_off,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    "No alarms saved.",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status and actions
                      Row(
                        children: [
                          Icon(
                            alarm.active ? Icons.alarm_on : Icons.alarm_off,
                            color: alarm.active ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              alarm.active ? "Active Alarm" : "Inactive Alarm",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: alarm.active ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                          Switch(
                            value: alarm.active,
                            onChanged: (value) async {
                              if (value) {
                                await _repo.activateAlarm(alarm.id!);
                              } else {
                                await _repo.deactivateAlarm(alarm.id!);
                              }
                            },
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Location details
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Location:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Latitude: ${alarm.destLat.toStringAsFixed(6)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              "Longitude: ${alarm.destLng.toStringAsFixed(6)}",
                              style: const TextStyle(fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            
                            const Text(
                              "Radius:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "${alarm.radiusM} meters",
                              style: const TextStyle(fontSize: 13),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            const Text(
                              "Sound:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              alarm.soundPath != null
                                  ? _getAudioFileName(alarm.soundPath!)
                                  : "Default alarm sound",
                              style: TextStyle(
                                fontSize: 13,
                                fontStyle: alarm.soundPath == null
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                                color: alarm.soundPath == null
                                    ? Colors.grey[600]
                                    : Colors.black,
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                            
                            const Text(
                              "Created:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(alarm.createdAt),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _viewOnMap(alarm),
                              icon: const Icon(Icons.map, size: 18),
                              label: const Text("View on Map"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _editAlarm(alarm),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text("Edit"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _deleteAlarm(alarm),
                            icon: const Icon(Icons.delete),
                            color: Colors.red,
                            tooltip: "Delete Alarm",
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _getAudioFileName(String path) {
    return path.split('/').last.split('\\').last;
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  void _viewOnMap(alarm) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          initialLocation: LatLng(alarm.destLat, alarm.destLng),
          initialRadius: alarm.radiusM,
        ),
      ),
    );
  }

  void _editAlarm(alarm) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => EditAlarmDialog(
        alarm: alarm,
        repository: _repo,
      ),
    );

    if (result == true && mounted) {
      // Changes were made, show confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Alarm updated successfully"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _deleteAlarm(alarm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Alarm"),
        content: const Text("Are you sure you want to delete this alarm?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repo.removeAlarm(alarm.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Alarm deleted"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

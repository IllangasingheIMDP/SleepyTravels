import 'package:flutter/material.dart';
import '../data/repositories/alarm_repository.dart';

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
            return const Center(child: Text("No alarms saved."));
          }

          return ListView.builder(
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return ListTile(
                title: Text("Radius: ${alarm.radiusM}m"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Lat: ${alarm.destLat}, Lng: ${alarm.destLng}"),
                    Text(
                      alarm.active ? "Status: Active" : "Status: Inactive",
                      style: TextStyle(
                        color: alarm.active ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: alarm.active,
                      onChanged: (value) async {
                        if (value) {
                          // Activate alarm
                          await _repo.activateAlarm(alarm.id!);
                        } else {
                          // Deactivate alarm
                          await _repo.deactivateAlarm(alarm.id!);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        await _repo.removeAlarm(alarm.id!);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

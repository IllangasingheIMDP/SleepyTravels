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
    const Color primaryGold = Color(0xFFF0CB46);
    const Color cardBackground = Color(0xFF001D3D);
    const Color navyBlue = Color(0xFF003566);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryGold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.alarm, color: primaryGold, size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              "Saved Alarms",
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, child) {
          final alarms = _repo.items;
          if (alarms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: primaryGold.withOpacity(0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGold.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.alarm_off,
                      size: 64,
                      color: primaryGold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "No alarms saved.",
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create your first alarm from the map",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12.0),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                decoration: BoxDecoration(
                  color: cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: alarm.active
                        ? primaryGold.withOpacity(0.5)
                        : primaryGold.withOpacity(0.2),
                    width: alarm.active ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: alarm.active
                          ? primaryGold.withOpacity(0.3)
                          : primaryGold.withOpacity(0.1),
                      blurRadius: alarm.active ? 16 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with status and actions
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: alarm.active
                                  ? primaryGold.withOpacity(0.2)
                                  : Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              alarm.active ? Icons.alarm_on : Icons.alarm_off,
                              color: alarm.active
                                  ? primaryGold
                                  : Colors.white.withOpacity(0.7),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alarm.active ? "Active Alarm" : "Inactive Alarm",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: alarm.active
                                    ? primaryGold
                                    : Colors.white.withOpacity(0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: navyBlue.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: primaryGold.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Switch(
                              value: alarm.active,
                              onChanged: (value) async {
                                if (value) {
                                  await _repo.activateAlarm(alarm.id!);
                                } else {
                                  await _repo.deactivateAlarm(alarm.id!);
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Location details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: navyBlue,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryGold.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow(
                              Icons.location_on,
                              "Location:",
                              "Lat: ${alarm.destLat.toStringAsFixed(6)}\nLng: ${alarm.destLng.toStringAsFixed(6)}",
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.radio_button_checked,
                              "Radius:",
                              "${alarm.radiusM} meters",
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.audiotrack,
                              "Sound:",
                              alarm.soundPath != null
                                  ? _getAudioFileName(alarm.soundPath!)
                                  : "Default alarm sound",
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow(
                              Icons.access_time,
                              "Created:",
                              _formatDate(alarm.createdAt),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              onPressed: () => _viewOnMap(alarm),
                              icon: Icons.map,
                              label: "View on Map",
                              color: navyBlue,
                              textColor: primaryGold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildActionButton(
                              onPressed: () => _editAlarm(alarm),
                              icon: Icons.edit,
                              label: "Edit",
                              color: const Color(0xFFCCA000),
                              textColor: const Color(0xFF001D3D),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.red.shade700,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: IconButton(
                              onPressed: () => _deleteAlarm(alarm),
                              icon: const Icon(Icons.delete),
                              color: Colors.white,
                              tooltip: "Delete Alarm",
                            ),
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    const Color primaryGold = Color(0xFFF0CB46);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: primaryGold.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: primaryGold, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: primaryGold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        icon: Icon(icon, size: 16, color: textColor),
        label: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
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
      builder: (context) => EditAlarmDialog(alarm: alarm, repository: _repo),
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

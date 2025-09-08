import 'package:flutter/material.dart';
import '../data/repositories/log_repository.dart';
import '../data/models/log_model.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LogRepository _repo = LogRepository();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Give the repository time to load
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Triggered Logs"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _repo.reload(); // Reload the data
            },
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              _clearAllLogs();
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, child) {
          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = _repo.items;
          if (logs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.history,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No alarm logs available",
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Logs will appear here when alarms are triggered",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      _addTestLog(); // Add a test log for demonstration
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add Test Log"),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange,
                    child: const Icon(
                      Icons.alarm,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    "Alarm Triggered",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Time: ${_formatDate(log.triggeredAt)}"),
                      Text("Location: ${log.lat.toStringAsFixed(6)}, ${log.lng.toStringAsFixed(6)}"),
                      if (log.alarmId != null) Text("Alarm ID: ${log.alarmId}"),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteLog(log),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}";
  }

  Future<void> _addTestLog() async {
    final testLog = LogModel(
      alarmId: 1,
      triggeredAt: DateTime.now().millisecondsSinceEpoch,
      lat: 37.7749,
      lng: -122.4194,
    );
    
    await _repo.addLog(testLog);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test log added")),
      );
    }
  }

  Future<void> _deleteLog(LogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Log"),
        content: const Text("Are you sure you want to delete this log entry?"),
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

    if (confirmed == true && log.id != null) {
      await _repo.removeLog(log.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Log deleted"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllLogs() async {
    if (_repo.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No logs to clear")),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear All Logs"),
        content: Text("Are you sure you want to delete all ${_repo.items.length} log entries?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Clear All"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final logCount = _repo.items.length;
        await _repo.clearAllLogs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("$logCount logs cleared"),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print('Error clearing logs: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error clearing logs: $e")),
          );
        }
      }
    }
  }
}

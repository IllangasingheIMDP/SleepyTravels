import 'package:flutter/material.dart';
import '../data/repositories/log_repository.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final LogRepository _repo = LogRepository();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Triggered Logs")),
      body: ListenableBuilder(
        listenable: _repo,
        builder: (context, child) {
          final logs = _repo.items;
          if (logs.isEmpty) {
            return const Center(child: Text("No logs available."));
          }

          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                title: Text("Triggered at ${log.triggeredAt}"),
                subtitle: Text("Lat: ${log.lat}, Lng: ${log.lng}"),
              );
            },
          );
        },
      ),
    );
  }
}

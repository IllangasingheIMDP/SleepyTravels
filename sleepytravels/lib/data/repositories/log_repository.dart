import 'package:flutter/material.dart';
import '../../core/services/db_service.dart';
import '../models/log_model.dart';

class LogRepository extends ChangeNotifier {
  final List<LogModel> _items = [];

  List<LogModel> get items => List.unmodifiable(_items);

  LogRepository() {
    _load();
  }

  Future<void> _load() async {
    final rows = await DBService.instance.query('logs');
    _items.clear();
    for (final r in rows) {
      _items.add(LogModel.fromMap(r));
    }
    notifyListeners();
  }

  Future<void> addLog(LogModel log) async {
    final id = await DBService.instance.insert('logs', {
      'alarm_id': log.alarmId,
      'triggered_at': log.triggeredAt,
      'lat': log.lat,
      'lng': log.lng,
    });
    log.id = id;
    _items.add(log);
    notifyListeners();
  }

  Future<void> removeLog(int id) async {
    await DBService.instance.delete('logs', id);
    _items.removeWhere((l) => l.id == id);
    notifyListeners();
  }
}

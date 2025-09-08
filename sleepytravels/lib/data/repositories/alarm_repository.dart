import 'package:flutter/material.dart';
import '../../core/services/db_service.dart';
import '../models/alarm_model.dart';

class AlarmRepository extends ChangeNotifier {
  Future<void> deactivateAlarm(int id) async {
    try {
      final alarm = _items.firstWhere((a) => a.id == id);
      alarm.active = false;
      await DBService.instance.rawUpdate(
        'UPDATE alarms SET active = 0 WHERE id = ?',
        [id],
      );
      notifyListeners();
    } catch (e) {
      // Alarm not found, do nothing
    }
  }

  Future<void> activateAlarm(int id) async {
    try {
      final alarm = _items.firstWhere((a) => a.id == id);
      alarm.active = true;
      await DBService.instance.rawUpdate(
        'UPDATE alarms SET active = 1 WHERE id = ?',
        [id],
      );
      notifyListeners();
    } catch (e) {
      // Alarm not found, do nothing
    }
  }

  final List<AlarmModel> _items = [];

  List<AlarmModel> get items => List.unmodifiable(_items);

  AlarmRepository() {
    _load();
  }

  Future<void> _load() async {
    final rows = await DBService.instance.query('alarms');
    _items.clear();
    for (final r in rows) {
      _items.add(AlarmModel.fromMap(r));
    }
    notifyListeners();
  }

  Future<void> addAlarm(AlarmModel alarm) async {
    final id = await DBService.instance.insert('alarms', {
      'dest_lat': alarm.destLat,
      'dest_lng': alarm.destLng,
      'radius_m': alarm.radiusM,
      'sound_path': alarm.soundPath,
      'created_at': alarm.createdAt,
      'active': alarm.active ? 1 : 0,
    });
    alarm.id = id;
    _items.add(alarm);
    notifyListeners();

    // Debug: Print the alarm that was added
    
  }

  List<AlarmModel> getActiveAlarms() {
    return _items.where((a) => a.active).toList(growable: false);
  }

  Future<List<AlarmModel>> getActiveAlarmsFromDB() async {
    final rows = await DBService.instance.query('alarms');
    final allAlarms = rows.map((r) => AlarmModel.fromMap(r)).toList();
    final activeAlarms = allAlarms.where((a) => a.active).toList();

   
 
    return activeAlarms;
  }

  Future<void> removeAlarm(int id) async {
    await DBService.instance.delete('alarms', id);
    _items.removeWhere((a) => a.id == id);
    notifyListeners();
  }
}

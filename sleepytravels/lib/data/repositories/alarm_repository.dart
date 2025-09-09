import 'package:flutter/material.dart';
import '../../core/services/db_service.dart';
import '../models/alarm_model.dart';
import '../../core/services/monitor_service.dart';
import 'dart:developer' as developer;
class AlarmRepository extends ChangeNotifier {
  Future<void> deactivateAlarm(int id) async {
    try {
      final alarm = _items.firstWhere((a) => a.id == id);
      alarm.active = false;
      await DBService.instance.rawUpdate(
        'UPDATE alarms SET active = 0 WHERE id = ?',
        [id],
      );

      // Update MonitorService cache
      MonitorService().removeAlarmFromCache(id);

      notifyListeners();
    } catch (e) {
      developer.log('AlarmRepository: Error deactivating alarm $id: $e');
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

      // Update MonitorService cache
      MonitorService().addAlarmToCache(alarm);

      notifyListeners();
    } catch (e) {
      developer.log('AlarmRepository: Error activating alarm $id: $e');
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

    // Update MonitorService cache if alarm is active
    if (alarm.active) {
      MonitorService().addAlarmToCache(alarm);
    }

    notifyListeners();
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

    // Update MonitorService cache
    MonitorService().removeAlarmFromCache(id);

    notifyListeners();
  }

  Future<void> updateAlarm(int id, int newRadius, String? newSoundPath) async {
    try {
      await DBService.instance.rawUpdate(
        'UPDATE alarms SET radius_m = ?, sound_path = ? WHERE id = ?',
        [newRadius, newSoundPath, id],
      );

      // Update the local copy
      final alarmIndex = _items.indexWhere((a) => a.id == id);
      if (alarmIndex != -1) {
        _items[alarmIndex].radiusM = newRadius;
        _items[alarmIndex].soundPath = newSoundPath;

        // Update MonitorService cache if alarm is active
        if (_items[alarmIndex].active) {
          MonitorService().updateAlarmInCache(_items[alarmIndex]);
        }
      }

      notifyListeners();
    } catch (e) {
      developer.log('Error updating alarm: $e');
      rethrow;
    }
  }
}

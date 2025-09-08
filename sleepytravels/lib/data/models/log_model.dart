class LogModel {
  int? id;
  int? alarmId;
  int triggeredAt;
  double lat;
  double lng;

  LogModel({
    this.id,
    this.alarmId,
    required this.triggeredAt,
    required this.lat,
    required this.lng,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'alarm_id': alarmId,
    'triggered_at': triggeredAt,
    'lat': lat,
    'lng': lng,
  };

  factory LogModel.fromMap(Map<String, Object?> m) => LogModel(
    id: m['id'] as int?,
    alarmId: m['alarm_id'] as int?,
    triggeredAt: (m['triggered_at'] as num).toInt(),
    lat: (m['lat'] as num).toDouble(),
    lng: (m['lng'] as num).toDouble(),
  );
}

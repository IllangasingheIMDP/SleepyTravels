class AlarmModel {
  int? id;
  double destLat;
  double destLng;
  int radiusM;
  String? soundPath;
  int createdAt;
  bool active;

  AlarmModel({
    this.id,
    required this.destLat,
    required this.destLng,
    required this.radiusM,
    this.soundPath,
    required this.createdAt,
    this.active = true,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'dest_lat': destLat,
    'dest_lng': destLng,
    'radius_m': radiusM,
    'sound_path': soundPath,
    'created_at': createdAt,
    'active': active ? 1 : 0,
  };

  factory AlarmModel.fromMap(Map<String, Object?> m) => AlarmModel(
    id: m['id'] as int?,
    destLat: (m['dest_lat'] as num).toDouble(),
    destLng: (m['dest_lng'] as num).toDouble(),
    radiusM: (m['radius_m'] as num).toInt(),
    soundPath: m['sound_path'] as String?,
    createdAt: (m['created_at'] as num).toInt(),
    active: (m['active'] ?? 1) == 1,
  );
}

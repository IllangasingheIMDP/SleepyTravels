import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBService {
  DBService._();
  static final DBService instance = DBService._();
  Database? _db;

  Future<void> init() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'sleepytravels.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
	CREATE TABLE alarms (
	id INTEGER PRIMARY KEY AUTOINCREMENT,
	dest_lat REAL NOT NULL,
	dest_lng REAL NOT NULL,
	radius_m INTEGER NOT NULL,
	sound_path TEXT,
	created_at INTEGER NOT NULL,
	active INTEGER NOT NULL DEFAULT 1
	)
	''');

        await db.execute('''
CREATE TABLE logs (
id INTEGER PRIMARY KEY AUTOINCREMENT,
alarm_id INTEGER,
triggered_at INTEGER,
lat REAL,
lng REAL
)
''');
      },
    );
  }

  Future<int> insert(String table, Map<String, Object?> data) async {
    return await _db!.insert(table, data);
  }

  Future<List<Map<String, Object?>>> query(String table) async {
    return await _db!.query(table);
  }

  Future<int> delete(String table, int id) async {
    return await _db!.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> rawUpdate(String sql, [List<Object?>? args]) async {
    return await _db!.rawUpdate(sql, args);
  }
}

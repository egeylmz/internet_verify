import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('usage_stats.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        mobile_mb REAL,
        wifi_mb REAL,
        day_of_week INTEGER
      )
    ''');
  }

  Future<int> insertOrUpdate(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      'daily_usage',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace, // Aynı gün varsa güncelle
    );
  }

  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await instance.database;
    return await db.query('daily_usage', orderBy: 'date DESC');
  }
}
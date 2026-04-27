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
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE daily_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT UNIQUE,
        mobile_mb REAL,
        wifi_mb REAL,
        operator_mb REAL,
        day_of_week INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE user_package (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quota_mb REAL NOT NULL,
        billing_day INTEGER NOT NULL
      )
    ''');
  }

  // v1→v2: operator_mb eklendi, v2→v3: user_package tablosu eklendi
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE daily_usage ADD COLUMN operator_mb REAL');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_package (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quota_mb REAL NOT NULL,
          billing_day INTEGER NOT NULL
        )
      ''');
    }
  }

  Future<int> insertOrUpdate(Map<String, dynamic> row) async {
    final db = await instance.database;
    return await db.insert(
      'daily_usage',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> batchInsertOrUpdate(List<Map<String, dynamic>> rows) async {
    final db = await instance.database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('daily_usage', row, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // Tüm satırları tarihe göre azalan sırada döndür
  Future<List<Map<String, dynamic>>> queryAllRows() async {
    final db = await instance.database;
    return await db.query('daily_usage', orderBy: 'date DESC');
  }

  // Son N günün kayıtlarını tarihe göre artan sırada döndür (tahmin için)
  Future<List<Map<String, dynamic>>> queryLastNDays(int n) async {
    final db = await instance.database;
    final cutoff = DateTime.now().subtract(Duration(days: n));
    final cutoffStr =
        "${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}";
    return await db.query(
      'daily_usage',
      where: 'date >= ?',
      whereArgs: [cutoffStr],
      orderBy: 'date ASC',
    );
  }

  // Belirli tarih aralığındaki kayıtları artan sırada döndür (doğrulama için)
  Future<List<Map<String, dynamic>>> queryByDateRange(
      String startDate, String endDate) async {
    final db = await instance.database;
    return await db.query(
      'daily_usage',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC',
    );
  }

  // Operatör verisini belirli bir gün için güncelle (PDF parse sonrası)
  Future<int> updateOperatorMb(String date, double operatorMb) async {
    final db = await instance.database;
    return await db.update(
      'daily_usage',
      {'operator_mb': operatorMb},
      where: 'date = ?',
      whereArgs: [date],
    );
  }

  // Kaç günlük veri var?
  Future<int> getRowCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM daily_usage');
    return (result.first['count'] as int?) ?? 0;
  }

  // Paket bilgisini kaydet (her zaman tek kayıt)
  Future<void> savePackageInfo({required double quotaMb, required int billingDay}) async {
    final db = await instance.database;
    await db.delete('user_package');
    await db.insert('user_package', {'quota_mb': quotaMb, 'billing_day': billingDay});
  }

  // Kayıtlı paket bilgisini getir
  Future<Map<String, dynamic>?> getPackageInfo() async {
    final db = await instance.database;
    final rows = await db.query('user_package', limit: 1);
    return rows.isNotEmpty ? rows.first : null;
  }
}

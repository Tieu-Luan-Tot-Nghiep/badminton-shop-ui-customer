import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AdminMasterDataLocalDataSource {
  AdminMasterDataLocalDataSource({Database? database}) : _database = database;

  static const _dbName = 'admin_cache.db';
  static const _table = 'admin_master_data';

  final Database? _database;
  Database? _db;

  Future<Database> get _instance async {
    if (_database != null) {
      return _database;
    }
    if (_db != null) {
      return _db!;
    }

    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            type TEXT NOT NULL,
            item_id TEXT NOT NULL,
            name TEXT NOT NULL,
            slug TEXT,
            PRIMARY KEY (type, item_id)
          )
        ''');
      },
    );

    return _db!;
  }

  Future<List<Map<String, dynamic>>> getCachedBrands() async {
    final db = await _instance;
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: ['brand'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => <String, dynamic>{'id': row['item_id'], 'name': row['name']},
        )
        .toList();
  }

  Future<List<Map<String, dynamic>>> getCachedCategories() async {
    final db = await _instance;
    final rows = await db.query(
      _table,
      where: 'type = ?',
      whereArgs: ['category'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => <String, dynamic>{
            'id': row['item_id'],
            'name': row['name'],
            'slug': row['slug'],
          },
        )
        .toList();
  }

  Future<void> cacheBrands(List<Map<String, dynamic>> brands) {
    return _cache(type: 'brand', items: brands);
  }

  Future<void> cacheCategories(List<Map<String, dynamic>> categories) {
    return _cache(type: 'category', items: categories);
  }

  Future<void> _cache({
    required String type,
    required List<Map<String, dynamic>> items,
  }) async {
    final db = await _instance;

    await db.transaction((txn) async {
      await txn.delete(_table, where: 'type = ?', whereArgs: [type]);

      for (final item in items) {
        final id = '${item['id'] ?? ''}'.trim();
        final name = '${item['name'] ?? ''}'.trim();
        if (id.isEmpty || name.isEmpty) {
          continue;
        }

        await txn.insert(_table, {
          'type': type,
          'item_id': id,
          'name': name,
          'slug': '${item['slug'] ?? ''}'.trim().isEmpty
              ? null
              : '${item['slug']}'.trim(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

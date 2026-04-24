import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'admin_remote_data_source.dart';

class AdminOrdersLocalDataSource {
  AdminOrdersLocalDataSource({Database? database}) : _database = database;

  static const _dbName = 'admin_cache.db';
  static const _metaTable = 'admin_orders_cache_meta';
  static const _itemsTable = 'admin_orders_cache_items';

  final Database? _database;
  Database? _db;

  Future<Database> get _instance async {
    if (_database != null) {
      await _ensureTables(_database);
      return _database;
    }
    if (_db != null) {
      return _db!;
    }

    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: (db, version) async {
        await _ensureTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _ensureTables(db);
      },
    );

    await _ensureTables(_db!);
    return _db!;
  }

  Future<void> _ensureTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_metaTable (
        cache_key TEXT PRIMARY KEY,
        page INTEGER NOT NULL,
        size INTEGER NOT NULL,
        total_elements INTEGER NOT NULL,
        total_pages INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_itemsTable (
        cache_key TEXT NOT NULL,
        item_index INTEGER NOT NULL,
        json TEXT NOT NULL,
        PRIMARY KEY (cache_key, item_index)
      )
    ''');
  }

  Future<void> cacheOrders(String cacheKey, AdminPageResult pageResult) async {
    final db = await _instance;

    await db.transaction((txn) async {
      await txn.delete(
        _itemsTable,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );

      await txn.insert(_metaTable, {
        'cache_key': cacheKey,
        'page': pageResult.page,
        'size': pageResult.size,
        'total_elements': pageResult.totalElements,
        'total_pages': pageResult.totalPages,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      for (var i = 0; i < pageResult.items.length; i++) {
        await txn.insert(_itemsTable, {
          'cache_key': cacheKey,
          'item_index': i,
          'json': jsonEncode(pageResult.items[i]),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<AdminPageResult?> getCachedOrders(String cacheKey) async {
    final db = await _instance;

    final metaRows = await db.query(
      _metaTable,
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      limit: 1,
    );

    if (metaRows.isEmpty) {
      return null;
    }

    final itemRows = await db.query(
      _itemsTable,
      where: 'cache_key = ?',
      whereArgs: [cacheKey],
      orderBy: 'item_index ASC',
    );

    final items = itemRows
        .map(
          (row) => Map<String, dynamic>.from(
            jsonDecode('${row['json']}') as Map<String, dynamic>,
          ),
        )
        .toList();

    final meta = metaRows.first;
    return AdminPageResult(
      items: items,
      page: (meta['page'] as num).toInt(),
      size: (meta['size'] as num).toInt(),
      totalElements: (meta['total_elements'] as num).toInt(),
      totalPages: (meta['total_pages'] as num).toInt(),
    );
  }
}

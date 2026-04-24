import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';

class HomeLocalDataSource {
  HomeLocalDataSource({Database? database}) : _database = database;

  static const _dbName = 'home_cache.db';
  static const _categoryTable = 'home_categories';
  static const _productTable = 'home_products';

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
          CREATE TABLE $_categoryTable (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            slug TEXT NOT NULL,
            icon_url TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE $_productTable (
            id TEXT NOT NULL,
            section TEXT NOT NULL,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            image_url TEXT,
            rating REAL,
            is_new INTEGER NOT NULL,
            is_featured INTEGER NOT NULL,
            PRIMARY KEY (id, section)
          )
        ''');
      },
    );

    return _db!;
  }

  Future<List<CategoryModel>> getCachedCategories() async {
    final db = await _instance;
    final rows = await db.query(_categoryTable, orderBy: 'name ASC');
    return rows.map(CategoryModel.fromCache).toList();
  }

  Future<List<ProductModel>> getCachedProducts({
    required String section,
  }) async {
    final db = await _instance;
    final rows = await db.query(
      _productTable,
      where: 'section = ?',
      whereArgs: [section],
      orderBy: 'rowid DESC',
    );
    return rows.map(ProductModel.fromCache).toList();
  }

  Future<void> cacheCategories(List<CategoryModel> categories) async {
    final db = await _instance;
    await db.transaction((txn) async {
      await txn.delete(_categoryTable);
      for (final item in categories) {
        await txn.insert(
          _categoryTable,
          item.toCache(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<void> cacheProducts({
    required String section,
    required List<ProductModel> products,
  }) async {
    final db = await _instance;
    await db.transaction((txn) async {
      await txn.delete(
        _productTable,
        where: 'section = ?',
        whereArgs: [section],
      );
      for (final item in products) {
        await txn.insert(
          _productTable,
          item.toCache(section: section),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

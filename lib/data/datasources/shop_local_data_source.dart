import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category_model.dart';
import '../models/product_model.dart';

class ShopLocalDataSource {
  ShopLocalDataSource({Database? database}) : _database = database;

  static const _dbName = 'shop_cache.db';
  static const _categoryTable = 'shop_first_categories';
  static const _productTable = 'shop_first_products';

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
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            price REAL NOT NULL,
            image_url TEXT,
            rating REAL,
            is_new INTEGER NOT NULL,
            is_featured INTEGER NOT NULL
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

  Future<List<ProductModel>> getCachedFirstProducts() async {
    final db = await _instance;
    final rows = await db.query(_productTable, orderBy: 'rowid ASC');
    return rows.map(ProductModel.fromCache).toList();
  }

  Future<void> cacheFirstPage({
    required List<CategoryModel> categories,
    required List<ProductModel> products,
  }) async {
    final db = await _instance;
    await db.transaction((txn) async {
      await txn.delete(_categoryTable);
      await txn.delete(_productTable);

      for (final c in categories) {
        await txn.insert(
          _categoryTable,
          c.toCache(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      for (final p in products) {
        final row = p.toCache(section: 'catalog_first_page');
        await txn.insert(_productTable, {
          'id': row['id'],
          'name': row['name'],
          'price': row['price'],
          'image_url': row['image_url'],
          'rating': row['rating'],
          'is_new': row['is_new'],
          'is_featured': row['is_featured'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
}

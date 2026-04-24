import '../../domain/entities/category_entity.dart';
import '../../domain/entities/home_feed_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/repositories/home_repository.dart';
import '../datasources/home_local_data_source.dart';
import '../datasources/home_remote_data_source.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl(this._remote, this._local);

  final HomeRemoteDataSource _remote;
  final HomeLocalDataSource _local;

  static const _featuredSection = 'featured';
  static const _newestSection = 'newest';

  @override
  Future<List<CategoryEntity>> getAllCategories() async {
    final data = await _remote.getAllCategories();
    return data.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<ProductEntity>> getFeaturedProducts({int limit = 8}) async {
    final data = await _remote.getFeaturedProducts(limit: limit);
    return data.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<ProductEntity>> getNewestProducts({int limit = 8}) async {
    final data = await _remote.getNewestProducts(limit: limit);
    return data.map((e) => e.toEntity()).toList();
  }

  @override
  Stream<HomeFeedEntity> watchHomeFeed({int limit = 8}) async* {
    final cachedCategories = await _local.getCachedCategories();
    final cachedFeatured = await _local.getCachedProducts(
      section: _featuredSection,
    );
    final cachedNewest = await _local.getCachedProducts(
      section: _newestSection,
    );

    final hasCache =
        cachedCategories.isNotEmpty ||
        cachedFeatured.isNotEmpty ||
        cachedNewest.isNotEmpty;

    if (hasCache) {
      yield _toHomeFeed(cachedCategories, cachedFeatured, cachedNewest);
    }

    try {
      final categoriesFuture = _remote.getAllCategories();
      final featuredFuture = _remote.getFeaturedProducts(limit: limit);
      final newestFuture = _remote.getNewestProducts(limit: limit);

      final categories = await categoriesFuture;
      final featured = await featuredFuture;
      final newest = await newestFuture;

      await _local.cacheCategories(categories);
      await _local.cacheProducts(section: _featuredSection, products: featured);
      await _local.cacheProducts(section: _newestSection, products: newest);

      yield _toHomeFeed(categories, featured, newest);
    } catch (e) {
      if (!hasCache) {
        rethrow;
      }
    }
  }

  HomeFeedEntity _toHomeFeed(
    List<CategoryModel> categories,
    List<ProductModel> featured,
    List<ProductModel> newest,
  ) {
    return HomeFeedEntity(
      categories: categories.map((e) => e.toEntity()).toList(),
      featuredProducts: featured.map((e) => e.toEntity()).toList(),
      newestProducts: newest.map((e) => e.toEntity()).toList(),
    );
  }
}

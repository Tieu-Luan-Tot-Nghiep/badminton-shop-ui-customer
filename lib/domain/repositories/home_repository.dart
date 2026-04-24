import '../entities/category_entity.dart';
import '../entities/home_feed_entity.dart';
import '../entities/product_entity.dart';

abstract class HomeRepository {
  Future<List<CategoryEntity>> getAllCategories();
  Future<List<ProductEntity>> getFeaturedProducts({int limit = 8});
  Future<List<ProductEntity>> getNewestProducts({int limit = 8});

  Stream<HomeFeedEntity> watchHomeFeed({int limit = 8});
}

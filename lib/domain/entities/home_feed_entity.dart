import 'category_entity.dart';
import 'product_entity.dart';

class HomeFeedEntity {
  const HomeFeedEntity({
    required this.categories,
    required this.featuredProducts,
    required this.newestProducts,
  });

  final List<CategoryEntity> categories;
  final List<ProductEntity> featuredProducts;
  final List<ProductEntity> newestProducts;
}

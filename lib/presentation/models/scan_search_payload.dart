import '../../domain/entities/product_entity.dart';

class ScanSearchPayload {
  const ScanSearchPayload({required this.products, required this.imagePath});

  final List<ProductEntity> products;
  final String imagePath;
}

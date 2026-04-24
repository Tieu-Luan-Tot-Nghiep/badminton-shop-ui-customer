class ProductEntity {
  const ProductEntity({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.rating,
    this.isNew = false,
    this.isFeatured = false,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final double? rating;
  final bool isNew;
  final bool isFeatured;
}

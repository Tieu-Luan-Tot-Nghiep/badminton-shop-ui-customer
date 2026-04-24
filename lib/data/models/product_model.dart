import '../../domain/entities/product_entity.dart';

class ProductModel {
  const ProductModel({
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

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final images = json['productImages'];
    String? firstImage;
    if (images is List && images.isNotEmpty) {
      final item = images.first;
      if (item is Map<String, dynamic>) {
        firstImage = item['imageUrl']?.toString() ?? item['url']?.toString();
      }
    }

    return ProductModel(
      id: '${json['id'] ?? json['productId'] ?? ''}',
      name: '${json['name'] ?? json['productName'] ?? 'Unknown Product'}',
      price: _toDouble(json['basePrice'] ?? json['price'] ?? 0),
      imageUrl:
          json['thumbnailUrl']?.toString() ??
          json['imageUrl']?.toString() ??
          firstImage,
      rating: json['rating'] == null ? null : _toDouble(json['rating']),
      isNew: json['isNew'] == true,
      isFeatured: json['isFeatured'] == true,
    );
  }

  factory ProductModel.fromCache(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'Unknown Product',
      price: _toDouble(map['price']),
      imageUrl: map['image_url']?.toString(),
      rating: map['rating'] == null ? null : _toDouble(map['rating']),
      isNew: (map['is_new'] as int? ?? 0) == 1,
      isFeatured: (map['is_featured'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toCache({required String section}) {
    return {
      'id': id,
      'section': section,
      'name': name,
      'price': price,
      'image_url': imageUrl,
      'rating': rating,
      'is_new': isNew ? 1 : 0,
      'is_featured': isFeatured ? 1 : 0,
    };
  }

  static double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value') ?? 0;
  }

  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      rating: rating,
      isNew: isNew,
      isFeatured: isFeatured,
    );
  }
}

import '../../domain/entities/review_entity.dart';

class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final String id;
  final String productId;
  final String productName;
  final String productImage;
  final double rating;
  final String comment;
  final String createdAt;

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    return ReviewModel(
      id: '${json['id'] ?? ''}',
      productId: '${json['productId'] ?? ''}',
      productName: '${json['productName'] ?? 'Sản phẩm'}',
      productImage: '${json['productImage'] ?? json['thumbnailUrl'] ?? ''}',
      rating: (json['rating'] ?? 0).toDouble(),
      comment: '${json['comment'] ?? ''}',
      createdAt: '${json['createdAt'] ?? DateTime.now().toIso8601String()}',
    );
  }

  ReviewEntity toEntity() => ReviewEntity(
    id: id,
    productId: productId,
    productName: productName,
    productImage: productImage,
    rating: rating,
    comment: comment,
    createdAt: createdAt,
  );
}

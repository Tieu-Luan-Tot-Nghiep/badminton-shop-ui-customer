class ReviewEntity {
  const ReviewEntity({
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
}

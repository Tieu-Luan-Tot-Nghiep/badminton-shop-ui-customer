import 'package:flutter/foundation.dart';
import '../../domain/entities/review_entity.dart';
import '../../domain/repositories/review_repository.dart';
import '../manager/auth_controller.dart';

class ReviewController extends ChangeNotifier {
  ReviewController(this._repository, this._authController);

  final ReviewRepository _repository;
  final AuthController _authController;

  bool isLoading = false;
  String? error;
  List<ReviewEntity> reviews = [];
  int totalReviews = 0;

  Future<void> fetchMyReviews() async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) {
      error = 'Unauthorized';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    notifyListeners();

    try {
      final list = await _repository.getMyReviews(token);
      reviews = list;
      totalReviews = list.length; // Simplified for this task
    } catch (e) {
      error = e.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteReview(String id) async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) return false;

    try {
      await _repository.deleteReview(token, id);
      reviews.removeWhere((e) => e.id == id);
      totalReviews = reviews.length;
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateReview(String id, double rating, String comment) async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) return false;

    try {
      await _repository.updateReview(token, id, rating, comment);
      final index = reviews.indexWhere((e) => e.id == id);
      if (index != -1) {
        final old = reviews[index];
        reviews[index] = ReviewEntity(
          id: old.id,
          productId: old.productId,
          productName: old.productName,
          productImage: old.productImage,
          rating: rating,
          comment: comment,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }
}

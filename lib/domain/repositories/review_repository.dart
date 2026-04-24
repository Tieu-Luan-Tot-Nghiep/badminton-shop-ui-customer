import '../../data/datasources/review_remote_data_source.dart';
import '../entities/review_entity.dart';

abstract class ReviewRepository {
  Future<List<ReviewEntity>> getMyReviews(String token, {int page = 0, int size = 10});
  Future<void> updateReview(String token, String id, double rating, String comment);
  Future<void> deleteReview(String token, String id);
}

class ReviewRepositoryImpl implements ReviewRepository {
  ReviewRepositoryImpl(this._remote);

  final ReviewRemoteDataSource _remote;

  @override
  Future<List<ReviewEntity>> getMyReviews(String token, {int page = 0, int size = 10}) async {
    final list = await _remote.getMyReviews(token, page: page, size: size);
    return list.map((e) => e.toEntity()).toList();
  }

  @override
  Future<void> updateReview(String token, String id, double rating, String comment) async {
    await _remote.updateReview(token, id, rating, comment);
  }

  @override
  Future<void> deleteReview(String token, String id) async {
    await _remote.deleteReview(token, id);
  }
}

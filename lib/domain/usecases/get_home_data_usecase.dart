import '../entities/home_feed_entity.dart';
import '../repositories/home_repository.dart';

class GetHomeDataUseCase {
  const GetHomeDataUseCase(this._repository);

  final HomeRepository _repository;

  Stream<HomeFeedEntity> call({int limit = 8}) {
    return _repository.watchHomeFeed(limit: limit);
  }
}

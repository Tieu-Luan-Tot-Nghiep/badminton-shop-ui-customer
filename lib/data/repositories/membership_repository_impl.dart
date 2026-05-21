import '../../domain/entities/membership_entity.dart';
import '../../domain/repositories/membership_repository.dart';
import '../datasources/membership_remote_data_source.dart';

class MembershipRepositoryImpl implements MembershipRepository {
  MembershipRepositoryImpl(this._remote);

  final MembershipRemoteDataSource _remote;

  @override
  Future<MembershipEntity> getMyMembership(String token) async {
    final model = await _remote.getMyMembership(token);
    return model.toEntity();
  }

  @override
  Future<List<MembershipHistoryEntity>> getMyHistory(String token) async {
    final list = await _remote.getMyHistory(token);
    return list.map((e) => e.toEntity()).toList();
  }
}

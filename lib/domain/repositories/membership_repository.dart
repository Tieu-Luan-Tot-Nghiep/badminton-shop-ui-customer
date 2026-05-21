import '../entities/membership_entity.dart';

abstract class MembershipRepository {
  Future<MembershipEntity> getMyMembership(String token);
  Future<List<MembershipHistoryEntity>> getMyHistory(String token);
}

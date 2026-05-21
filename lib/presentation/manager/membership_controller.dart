import 'package:flutter/foundation.dart';
import '../../domain/entities/membership_entity.dart';
import '../../domain/repositories/membership_repository.dart';
import 'auth_controller.dart';

class MembershipController extends ChangeNotifier {
  MembershipController(this._repository, this._authController);

  final MembershipRepository _repository;
  final AuthController _authController;

  bool isLoading = false;
  String? errorMessage;
  MembershipEntity? membership;
  List<MembershipHistoryEntity> history = [];

  Future<void> load() async {
    final token = _authController.session?.token;
    if (token == null || token.isEmpty) {
      errorMessage = 'Bạn cần đăng nhập để xem tích điểm.';
      notifyListeners();
      return;
    }

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _repository.getMyMembership(token),
        _repository.getMyHistory(token),
      ]);
      membership = results[0] as MembershipEntity;
      history = results[1] as List<MembershipHistoryEntity>;
    } catch (e) {
      errorMessage = 'Không thể tải dữ liệu thành viên.';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}

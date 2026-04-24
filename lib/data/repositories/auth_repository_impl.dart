import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._remote);

  final AuthRemoteDataSource _remote;

  @override
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) {
    return _remote.register(
      username: username,
      email: email,
      password: password,
      phoneNumber: phoneNumber,
    );
  }

  @override
  Future<AuthSessionEntity> login({
    required String username,
    required String password,
  }) async {
    final response = await _remote.login(
      username: username,
      password: password,
    );
    return response.toEntity();
  }

  @override
  Future<AuthSessionEntity> refresh({required String refreshToken}) async {
    final response = await _remote.refresh(refreshToken: refreshToken);
    return response.toEntity();
  }

  @override
  Future<void> verifyEmail({required String token, required String email}) {
    return _remote.verifyEmail(token: token, email: email);
  }

  @override
  Future<void> resendVerification({required String email}) {
    return _remote.resendVerification(email: email);
  }

  @override
  Future<void> forgotPassword({required String email}) {
    return _remote.forgotPassword(email: email);
  }

  @override
  Future<AuthSessionEntity> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    String? email,
    String? uid,
    String? displayName,
  }) async {
    final response = await _remote.socialLogin(
      provider: provider,
      idToken: idToken,
      accessToken: accessToken,
      email: email,
      uid: uid,
      displayName: displayName,
    );
    return response.toEntity();
  }

  @override
  Future<UserProfileEntity> getCurrentUser(String token) async {
    final model = await _remote.getCurrentUser(token);
    return model.toEntity();
  }

  @override
  Future<void> updateProfile({
    required String token,
    required String fullName,
    required String phoneNumber,
    String? birthDate,
  }) {
    return _remote.updateProfile(
      token: token,
      fullName: fullName,
      phoneNumber: phoneNumber,
      birthDate: birthDate,
    );
  }

  @override
  Future<void> updateAvatar({
    required String token,
    required String imagePath,
  }) {
    return _remote.updateAvatar(token: token, imagePath: imagePath);
  }

  @override
  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  }) {
    return _remote.changePassword(
      token: token,
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
  }
}

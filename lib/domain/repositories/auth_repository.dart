import '../entities/auth_session_entity.dart';
import '../entities/user_profile_entity.dart';

abstract class AuthRepository {
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  });

  Future<AuthSessionEntity> login({
    required String username,
    required String password,
  });

  Future<AuthSessionEntity> refresh({required String refreshToken});

  Future<void> verifyEmail({required String token, required String email});

  Future<void> resendVerification({required String email});

  Future<void> forgotPassword({required String email});

  Future<AuthSessionEntity> socialLogin({
    required String provider,
    String? idToken,
    String? accessToken,
    String? email,
    String? uid,
    String? displayName,
  });

  Future<UserProfileEntity> getCurrentUser(String token);

  Future<void> updateProfile({
    required String token,
    required String fullName,
    required String phoneNumber,
    String? birthDate,
  });

  Future<void> updateAvatar({required String token, required String imagePath});

  Future<void> changePassword({
    required String token,
    required String oldPassword,
    required String newPassword,
  });
}

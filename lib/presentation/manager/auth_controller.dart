import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../domain/entities/auth_session_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/auth_repository.dart';

enum SocialProvider { google, facebook }

extension on SocialProvider {
  String get registrationId =>
      this == SocialProvider.google ? 'google' : 'facebook';
}

class AuthController extends ChangeNotifier {
  AuthController(this._repository, {FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  final AuthRepository _repository;
  final FlutterSecureStorage _storage;

  bool isLoading = false;
  String? errorMessage;
  String? infoMessage;
  AuthSessionEntity? session;
  UserProfileEntity? userProfile;
  bool _isRestoringSession = false;
  bool _didCheckVerifyLink = false;
  String? pendingVerificationEmail;
  bool canLoginAfterVerification = false;

  bool get isAuthenticated => session != null && session!.token.isNotEmpty;
  bool get isRestoringSession => _isRestoringSession;
  String? get userRole => (userProfile?.role ?? session?.role)?.toUpperCase();
  bool get isAdmin => userRole == 'ADMIN';

  Future<void> restoreSession() async {
    if (session != null || _isRestoringSession) {
      return;
    }

    _isRestoringSession = true;
    notifyListeners();

    try {
      final accessToken = await _storage.read(key: 'auth.accessToken');
      if (accessToken == null || accessToken.isEmpty) {
        return;
      }

      final refreshToken = await _storage.read(key: 'auth.refreshToken');
      final username = await _storage.read(key: 'auth.username');
      final role = await _storage.read(key: 'auth.role');

      session = AuthSessionEntity(
        token: accessToken,
        refreshToken: refreshToken,
        username: username,
        role: role,
      );

      // Fetch profile once session is restored
      await fetchProfile();
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<void> fetchProfile() async {
    final token = session?.token;
    if (token == null || token.isEmpty) return;

    try {
      userProfile = await _repository.getCurrentUser(token);
      notifyListeners();
    } catch (_) {
      // If profile fetch fails, we don't necessarily logout,
      // but UI might show generic info.
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String phoneNumber,
  }) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();

    try {
      await _repository.register(
        username: username,
        email: email,
        password: password,
        phoneNumber: phoneNumber,
      );
      pendingVerificationEmail = email;
      canLoginAfterVerification = false;
      infoMessage =
          'Đăng ký thành công. Vui lòng kiểm tra email để xác thực tài khoản trước khi đăng nhập.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      session = await _repository.login(username: username, password: password);
      if (session == null || session!.token.trim().isEmpty) {
        throw DioException(
          requestOptions: RequestOptions(path: '/api/auth/login'),
          error: 'Missing access token in login response',
          type: DioExceptionType.badResponse,
        );
      }
      await _persistSession(session!);
      await fetchProfile();
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshToken() async {
    final currentRefresh = session?.refreshToken;
    if (currentRefresh == null || currentRefresh.isEmpty) {
      return;
    }

    try {
      final refreshed = await _repository.refresh(refreshToken: currentRefresh);
      session = refreshed;
      await _persistSession(refreshed);
      notifyListeners();
    } catch (_) {
      session = null;
      userProfile = null;
      notifyListeners();
    }
  }

  Future<void> verifyEmailFromUri(Uri uri) async {
    if (_didCheckVerifyLink) {
      return;
    }
    _didCheckVerifyLink = true;

    final token = uri.queryParameters['token'];
    final email = uri.queryParameters['email'];

    if (token == null || token.isEmpty || email == null || email.isEmpty) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();

    try {
      await _repository.verifyEmail(token: token, email: email);
      pendingVerificationEmail = email;
      canLoginAfterVerification = true;
      infoMessage = 'Xác thực email thành công. Bạn có thể đăng nhập ngay.';
    } catch (e) {
      errorMessage = _toReadableError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> loginWithSocial(SocialProvider provider) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();

    try {
      String? idToken;
      String? email;
      String? uid;
      String? displayName;

      if (provider == SocialProvider.google) {
        final googleSignIn = GoogleSignIn.instance;
        await googleSignIn.initialize();
        final googleUser = await googleSignIn.authenticate();
        final googleAuth = googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final userCredential = await FirebaseAuth.instance.signInWithCredential(
          credential,
        );
        final firebaseUser = userCredential.user;
        idToken = await firebaseUser?.getIdToken();
        email = firebaseUser?.email;
        uid = firebaseUser?.uid;
        displayName = firebaseUser?.displayName;
      }

      session = await _repository.socialLogin(
        provider: provider.registrationId,
        idToken: idToken,
        email: email,
        uid: uid,
        displayName: displayName,
      );
      await _persistSession(session!);
      await fetchProfile();
      infoMessage = 'Đăng nhập thành công.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String phoneNumber,
    String? birthDate,
  }) async {
    final token = session?.token;
    if (token == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateProfile(
        token: token,
        fullName: fullName,
        phoneNumber: phoneNumber,
        birthDate: birthDate,
      );
      await fetchProfile();
      infoMessage = 'Cập nhật thông tin thành công.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAvatar(String imagePath) async {
    final token = session?.token;
    if (token == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateAvatar(token: token, imagePath: imagePath);
      await fetchProfile();
      infoMessage = 'Cập nhật ảnh đại diện thành công.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = session?.token;
    if (token == null) return false;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.changePassword(
        token: token,
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      infoMessage = 'Đổi mật khẩu thành công.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerificationEmail({required String email}) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();

    try {
      await _repository.resendVerification(email: email);
      pendingVerificationEmail = email;
      infoMessage =
          'Đã gửi lại email xác thực. Vui lòng kiểm tra hộp thư của bạn.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> forgotPassword({required String email}) async {
    isLoading = true;
    errorMessage = null;
    infoMessage = null;
    notifyListeners();

    try {
      await _repository.forgotPassword(email: email);
      infoMessage = 'Duong link xac nhan email da duoc gui ve email cua ban.';
      return true;
    } catch (e) {
      errorMessage = _toReadableError(e);
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    errorMessage = null;
    infoMessage = null;
    notifyListeners();
  }

  void setInfoMessage(String message) {
    infoMessage = message;
    notifyListeners();
  }

  void clearProfile() {
    userProfile = null;
    notifyListeners();
  }

  void logout() {
    session = null;
    userProfile = null;
    _clearPersistedSession();
    notifyListeners();
  }

  Future<void> _persistSession(AuthSessionEntity value) async {
    await _storage.write(key: 'auth.accessToken', value: value.token);
    await _storage.write(key: 'auth.refreshToken', value: value.refreshToken);
    await _storage.write(key: 'auth.username', value: value.username);
    await _storage.write(key: 'auth.role', value: value.role);
  }

  Future<void> _clearPersistedSession() async {
    await _storage.delete(key: 'auth.accessToken');
    await _storage.delete(key: 'auth.refreshToken');
    await _storage.delete(key: 'auth.username');
    await _storage.delete(key: 'auth.role');
  }

  String _toReadableError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final serverMessage = _extractServerMessage(error.response?.data);

      if (status == 400) {
        return serverMessage ?? 'Thiếu hoặc sai dữ liệu đăng nhập Google.';
      }
      if (status == 401) {
        return serverMessage ??
            'Google token không hợp lệ, đã hết hạn hoặc email đã đăng ký bằng phương thức khác.';
      }
      if (status == 429) {
        return serverMessage ??
            'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
      }
      if (status == 503) {
        return serverMessage ??
            'Dịch vụ đăng nhập Google đang tạm thời gián đoạn. Vui lòng thử lại sau.';
      }
      if (status == 500) {
        return serverMessage ?? 'Máy chủ đang gặp lỗi. Vui lòng thử lại sau.';
      }

      if (status != null) {
        return serverMessage ?? 'Không thể xử lý đăng nhập (HTTP $status).';
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        return 'Không thể kết nối máy chủ. Vui lòng kiểm tra mạng và thử lại.';
      }
    }

    final text = error.toString();
    if (text.contains('401')) {
      return 'Thông tin đăng nhập chưa đúng hoặc tài khoản chưa xác thực.';
    }
    if (text.contains('400')) {
      return 'Dữ liệu không hợp lệ. Vui lòng kiểm tra lại thông tin.';
    }
    return 'Không thể kết nối máy chủ. Vui lòng thử lại.';
  }

  String? _extractServerMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final raw = data['message'];
      if (raw != null) {
        final message = raw.toString().trim();
        if (message.isNotEmpty) {
          return message;
        }
      }
    }
    return null;
  }
}

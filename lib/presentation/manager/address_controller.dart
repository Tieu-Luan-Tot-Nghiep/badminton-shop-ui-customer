import 'package:flutter/foundation.dart';
import '../../domain/entities/address_entity.dart';
import '../../domain/repositories/address_repository.dart';
import 'auth_controller.dart';

class AddressController extends ChangeNotifier {
  AddressController(this._repository, this._authController);

  final AddressRepository _repository;
  final AuthController _authController;

  List<AddressEntity> _addresses = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AddressEntity> get addresses => _addresses;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  String? get _token => _authController.session?.token;

  Future<void> loadAddresses() async {
    final token = _token;
    if (token == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _addresses = await _repository.getAllAddresses(token);
    } catch (e) {
      _errorMessage = 'Không thể tải danh sách địa chỉ.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addAddress(AddressEntity address) async {
    final token = _token;
    if (token == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _repository.createAddress(token, address);
      await loadAddresses();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể thêm địa chỉ mới.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateAddress(AddressEntity address) async {
    final token = _token;
    if (token == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      await _repository.updateAddress(token, address);
      await loadAddresses();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể cập nhật địa chỉ.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteAddress(int id) async {
    final token = _token;
    if (token == null) return false;

    try {
      await _repository.deleteAddress(token, id);
      await loadAddresses();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể xóa địa chỉ.';
      return false;
    }
  }

  Future<bool> setDefaultAddress(int id) async {
    final token = _token;
    if (token == null) return false;

    try {
      await _repository.setDefaultAddress(token, id);
      await loadAddresses();
      return true;
    } catch (e) {
      _errorMessage = 'Không thể đặt làm địa chỉ mặc định.';
      return false;
    }
  }
}

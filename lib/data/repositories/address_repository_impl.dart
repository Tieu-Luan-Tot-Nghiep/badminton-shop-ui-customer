import '../../domain/entities/address_entity.dart';
import '../../domain/repositories/address_repository.dart';
import '../datasources/address_remote_data_source.dart';
import '../models/address_model.dart';

class AddressRepositoryImpl implements AddressRepository {
  AddressRepositoryImpl(this._remote);

  final AddressRemoteDataSource _remote;

  @override
  Future<List<AddressEntity>> getAllAddresses(String token) async {
    final models = await _remote.getAllAddresses(token);
    return models.map((e) => e.toEntity()).toList();
  }

  @override
  Future<AddressEntity> createAddress(String token, AddressEntity address) async {
    final model = await _remote.createAddress(token, AddressModel.fromEntity(address));
    return model.toEntity();
  }

  @override
  Future<AddressEntity> updateAddress(String token, AddressEntity address) async {
    final model = await _remote.updateAddress(token, AddressModel.fromEntity(address));
    return model.toEntity();
  }

  @override
  Future<void> deleteAddress(String token, int id) {
    return _remote.deleteAddress(token, id);
  }

  @override
  Future<void> setDefaultAddress(String token, int id) {
    return _remote.setDefaultAddress(token, id);
  }
}

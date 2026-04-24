import '../entities/address_entity.dart';

abstract class AddressRepository {
  Future<List<AddressEntity>> getAllAddresses(String token);
  Future<AddressEntity> createAddress(String token, AddressEntity address);
  Future<AddressEntity> updateAddress(String token, AddressEntity address);
  Future<void> deleteAddress(String token, int id);
  Future<void> setDefaultAddress(String token, int id);
}

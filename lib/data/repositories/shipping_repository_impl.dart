import '../../domain/entities/province_entity.dart';
import '../../domain/entities/district_entity.dart';
import '../../domain/entities/ward_entity.dart';
import '../../domain/repositories/shipping_repository.dart';
import '../datasources/shipping_remote_data_source.dart';

class ShippingRepositoryImpl implements ShippingRepository {
  ShippingRepositoryImpl(this._remote);

  final ShippingRemoteDataSource _remote;

  @override
  Future<List<ProvinceEntity>> getProvinces() async {
    final models = await _remote.getProvinces();
    return models.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<DistrictEntity>> getDistricts(int provinceId) async {
    final models = await _remote.getDistricts(provinceId);
    return models.map((e) => e.toEntity()).toList();
  }

  @override
  Future<List<WardEntity>> getWards(int districtId) async {
    final models = await _remote.getWards(districtId);
    return models.map((e) => e.toEntity()).toList();
  }
}

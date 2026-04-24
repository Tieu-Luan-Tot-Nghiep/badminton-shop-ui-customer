import '../entities/province_entity.dart';
import '../entities/district_entity.dart';
import '../entities/ward_entity.dart';

abstract class ShippingRepository {
  Future<List<ProvinceEntity>> getProvinces();
  Future<List<DistrictEntity>> getDistricts(int provinceId);
  Future<List<WardEntity>> getWards(int districtId);
}

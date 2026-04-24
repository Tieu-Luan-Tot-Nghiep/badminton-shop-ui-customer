import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/province_model.dart';
import '../models/district_model.dart';
import '../models/ward_model.dart';

class ShippingRemoteDataSource {
  ShippingRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<ProvinceModel>> getProvinces() async {
    final response = await _dio.get('/api/shipping/provinces');
    final data = _extractData(response.data);
    if (data is List) {
      return data.map((e) => ProvinceModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<DistrictModel>> getDistricts(int provinceId) async {
    final response = await _dio.get('/api/shipping/provinces/$provinceId/districts');
    final data = _extractData(response.data);
    if (data is List) {
      return data.map((e) => DistrictModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<List<WardModel>> getWards(int districtId) async {
    final response = await _dio.get('/api/shipping/districts/$districtId/wards');
    final data = _extractData(response.data);
    if (data is List) {
      return data.map((e) => WardModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  dynamic _extractData(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload['data'] ?? payload;
    }
    return payload;
  }
}

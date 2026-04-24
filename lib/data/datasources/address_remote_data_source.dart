import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../models/address_model.dart';

class AddressRemoteDataSource {
  AddressRemoteDataSource({Dio? dio}) : _dio = dio ?? ApiClient.instance;

  final Dio _dio;

  Future<List<AddressModel>> getAllAddresses(String token) async {
    final response = await _dio.get(
      '/api/addresses',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return _parseList(response.data).map(AddressModel.fromJson).toList();
  }

  Future<AddressModel> createAddress(String token, AddressModel address) async {
    final response = await _dio.post(
      '/api/addresses',
      data: address.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AddressModel.fromJson(_pickEnvelope(response.data));
  }

  Future<AddressModel> updateAddress(String token, AddressModel address) async {
    final response = await _dio.put(
      '/api/addresses/${address.id}',
      data: address.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    return AddressModel.fromJson(_pickEnvelope(response.data));
  }

  Future<void> deleteAddress(String token, int id) async {
    await _dio.delete(
      '/api/addresses/$id',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  Future<void> setDefaultAddress(String token, int id) async {
    await _dio.patch(
      '/api/addresses/$id/default',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }

  List<Map<String, dynamic>> _parseList(dynamic payload) {
    if (payload is List) return payload.whereType<Map<String, dynamic>>().toList();
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _pickEnvelope(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is Map<String, dynamic>) return data;
      return payload;
    }
    return const {};
  }
}

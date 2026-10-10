import 'package:dio/dio.dart';

import 'api_client.dart';
import 'models.dart';

class VaultApi {
  final ApiClient _client;

  VaultApi(this._client);

  Future<int> latestVersion() async {
    final response = await _client.dio.get('/vault/records/version');
    return response.data['latestVersion'] as int;
  }

  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async {
    final response = await _client.dio.get(
      '/vault/records',
      queryParameters: {'since_version': sinceVersion},
    );
    final items = response.data as List<dynamic>;
    return items
        .map((e) => VaultRecordResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async {
    try {
      final response = await _client.dio.post(
        '/vault/records',
        data: records.map((r) => r.toJson()).toList(),
      );
      final items = response.data as List<dynamic>;
      return items
          .map((e) => VaultRecordResponse.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 409) {
        throw VaultConflictException.fromResponseBody(
          e.response!.data as Map<String, dynamic>,
        );
      }
      rethrow;
    }
  }
}

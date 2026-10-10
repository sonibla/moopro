import 'package:dio/dio.dart';

import 'api_client.dart';

class MiscApi {
  final ApiClient _client;

  MiscApi(this._client);

  Future<bool> checkHealth() async {
    try {
      await _client.dio.get('/health', options: dioOptionsSkipAuth);
      return true;
    } on DioException {
      return false;
    }
  }
}

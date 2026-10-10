import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _override = String.fromEnvironment('API_BASE_URL');

  static const String baseUrl = _override != ''
      ? _override
      : (kDebugMode
            ? 'http://localhost:8000'
            : 'https://api.moopro.sonibla.com');
}

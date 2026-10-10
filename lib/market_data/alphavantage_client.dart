import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';

class AlphaVantageSymbolMatch {
  final String symbol;
  final String name;
  final String type;
  final String region;
  final String currency;

  const AlphaVantageSymbolMatch({
    required this.symbol,
    required this.name,
    required this.type,
    required this.region,
    required this.currency,
  });
}

class AlphaVantageQuote {
  final String symbol;
  final Decimal price;
  final DateTime asOf;

  const AlphaVantageQuote({
    required this.symbol,
    required this.price,
    required this.asOf,
  });
}

class AlphaVantageException implements Exception {
  final String message;
  final bool rateLimited;

  const AlphaVantageException(this.message, {this.rateLimited = false});

  @override
  String toString() => message;
}

class AlphaVantageClient {
  final Dio _dio;

  AlphaVantageClient({Dio? dio})
    : _dio = dio ?? Dio(BaseOptions(baseUrl: 'https://www.alphavantage.co'));

  Future<List<AlphaVantageSymbolMatch>> searchSymbols({
    required String apiKey,
    required String keywords,
  }) async {
    final json = await _get({
      'function': 'SYMBOL_SEARCH',
      'keywords': keywords,
      'apikey': apiKey,
    });
    final matches = _expectKey(json, 'bestMatches') as List<dynamic>;
    return [
      for (final m in matches.cast<Map<String, dynamic>>())
        AlphaVantageSymbolMatch(
          symbol: m['1. symbol'] as String,
          name: m['2. name'] as String,
          type: m['3. type'] as String,
          region: m['4. region'] as String,
          currency: m['8. currency'] as String,
        ),
    ];
  }

  Future<AlphaVantageQuote> fetchEquityQuote({
    required String apiKey,
    required String symbol,
  }) async {
    final json = await _get({
      'function': 'GLOBAL_QUOTE',
      'symbol': symbol,
      'apikey': apiKey,
    });
    final quote = _expectKey(json, 'Global Quote') as Map<String, dynamic>;
    if (quote.isEmpty) {
      throw AlphaVantageException('No quote found for symbol "$symbol"');
    }
    return AlphaVantageQuote(
      symbol: quote['01. symbol'] as String,
      price: Decimal.parse(quote['05. price'] as String),
      asOf: DateTime.parse(quote['07. latest trading day'] as String),
    );
  }

  Future<AlphaVantageQuote> fetchCryptoExchangeRate({
    required String apiKey,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final json = await _get({
      'function': 'CURRENCY_EXCHANGE_RATE',
      'from_currency': fromCurrency,
      'to_currency': toCurrency,
      'apikey': apiKey,
    });
    final rate =
        _expectKey(json, 'Realtime Currency Exchange Rate')
            as Map<String, dynamic>;
    final lastRefreshed = rate['6. Last Refreshed'] as String;
    return AlphaVantageQuote(
      symbol: rate['1. From_Currency Code'] as String,
      price: Decimal.parse(rate['5. Exchange Rate'] as String),
      asOf: DateTime.parse(lastRefreshed.split(' ').first),
    );
  }

  Future<Map<String, dynamic>> _get(Map<String, String> queryParameters) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/query',
        queryParameters: queryParameters,
      );
      return response.data ?? const {};
    } on DioException catch (e) {
      throw AlphaVantageException('Network error: ${e.message}');
    }
  }

  Object _expectKey(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value != null) return value;

    final errorText =
        (json['Error Message'] ??
                json['Information'] ??
                json['Note'] ??
                'Unexpected AlphaVantage response: $json')
            .toString();
    final rateLimited = RegExp(
      r'rate limit|requests per day',
      caseSensitive: false,
    ).hasMatch(errorText);
    throw AlphaVantageException(errorText, rateLimited: rateLimited);
  }
}

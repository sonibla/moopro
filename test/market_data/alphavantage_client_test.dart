import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/market_data/alphavantage_client.dart';

class _FakeAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) handler;

  _FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

AlphaVantageClient _buildClient(
  Future<ResponseBody> Function(RequestOptions options) handler,
) {
  final dio = Dio(BaseOptions(baseUrl: 'https://www.alphavantage.co'));
  dio.httpClientAdapter = _FakeAdapter(handler);
  return AlphaVantageClient(dio: dio);
}

ResponseBody _jsonResponse(String body) => ResponseBody.fromString(
  body,
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json; charset=utf-8'],
  },
);

void main() {
  group('AlphaVantageClient.searchSymbols', () {
    test('parses bestMatches', () async {
      final client = _buildClient((options) async {
        expect(options.queryParameters['function'], 'SYMBOL_SEARCH');
        expect(options.queryParameters['keywords'], 'tesco');
        return _jsonResponse(
          '{"bestMatches": [{'
          '"1. symbol": "TSCO.LON", "2. name": "Tesco PLC", '
          '"3. type": "Equity", "4. region": "United Kingdom", '
          '"5. marketOpen": "08:00", "6. marketClose": "16:30", '
          '"7. timezone": "UTC+01", "8. currency": "GBX", '
          '"9. matchScore": "0.7273"}]}',
        );
      });

      final matches = await client.searchSymbols(
        apiKey: 'key',
        keywords: 'tesco',
      );

      expect(matches, hasLength(1));
      expect(matches.single.symbol, 'TSCO.LON');
      expect(matches.single.name, 'Tesco PLC');
      expect(matches.single.currency, 'GBX');
    });
  });

  group('AlphaVantageClient.fetchEquityQuote', () {
    test('parses Global Quote', () async {
      final client = _buildClient((options) async {
        expect(options.queryParameters['function'], 'GLOBAL_QUOTE');
        expect(options.queryParameters['symbol'], 'IBM');
        return _jsonResponse(
          '{"Global Quote": {"01. symbol": "IBM", "02. open": "209.42", '
          '"03. high": "216.10", "04. low": "206.80", "05. price": "214.17", '
          '"06. volume": "10500966", "07. latest trading day": "2026-07-24", '
          '"08. previous close": "206.65", "09. change": "7.52", '
          '"10. change percent": "3.6390%"}}',
        );
      });

      final quote = await client.fetchEquityQuote(apiKey: 'key', symbol: 'IBM');

      expect(quote.symbol, 'IBM');
      expect(quote.price, Decimal.parse('214.17'));
      expect(quote.asOf, DateTime.parse('2026-07-24'));
    });

    test('throws when the quote object is empty (unknown symbol)', () async {
      final client = _buildClient((options) async {
        return _jsonResponse('{"Global Quote": {}}');
      });

      expect(
        () => client.fetchEquityQuote(apiKey: 'key', symbol: 'BOGUS'),
        throwsA(
          isA<AlphaVantageException>().having(
            (e) => e.rateLimited,
            'rateLimited',
            isFalse,
          ),
        ),
      );
    });
  });

  group('AlphaVantageClient.fetchCryptoExchangeRate', () {
    test('parses Realtime Currency Exchange Rate', () async {
      final client = _buildClient((options) async {
        expect(options.queryParameters['function'], 'CURRENCY_EXCHANGE_RATE');
        expect(options.queryParameters['from_currency'], 'BTC');
        expect(options.queryParameters['to_currency'], 'USD');
        return _jsonResponse(
          '{"Realtime Currency Exchange Rate": {'
          '"1. From_Currency Code": "BTC", "2. From_Currency Name": "Bitcoin", '
          '"3. To_Currency Code": "USD", "4. To_Currency Name": "US Dollar", '
          '"5. Exchange Rate": "65000.12345678", '
          '"6. Last Refreshed": "2026-07-24 10:00:00", '
          '"7. Time Zone": "UTC", "8. Bid Price": "65000.00", '
          '"9. Ask Price": "65000.50"}}',
        );
      });

      final quote = await client.fetchCryptoExchangeRate(
        apiKey: 'key',
        fromCurrency: 'BTC',
        toCurrency: 'USD',
      );

      expect(quote.symbol, 'BTC');
      expect(quote.price, Decimal.parse('65000.12345678'));
      expect(quote.asOf, DateTime.parse('2026-07-24'));
    });
  });

  group('AlphaVantageClient error handling', () {
    test('"Error Message" surfaces as a non-rate-limited exception', () async {
      final client = _buildClient((options) async {
        return _jsonResponse('{"Error Message": "Invalid API call."}');
      });

      expect(
        () => client.fetchEquityQuote(apiKey: 'key', symbol: 'BOGUS'),
        throwsA(
          isA<AlphaVantageException>()
              .having((e) => e.rateLimited, 'rateLimited', isFalse)
              .having(
                (e) => e.message,
                'message',
                contains('Invalid API call'),
              ),
        ),
      );
    });

    test(
      '"Information" mentioning the daily limit is flagged rateLimited',
      () async {
        final client = _buildClient((options) async {
          return _jsonResponse(
            '{"Information": "Thank you for using Alpha Vantage! Our standard '
            'API rate limit is 25 requests per day."}',
          );
        });

        expect(
          () => client.searchSymbols(apiKey: 'key', keywords: 'aapl'),
          throwsA(
            isA<AlphaVantageException>().having(
              (e) => e.rateLimited,
              'rateLimited',
              isTrue,
            ),
          ),
        );
      },
    );

    test('"Note" mentioning the daily limit is flagged rateLimited', () async {
      final client = _buildClient((options) async {
        return _jsonResponse(
          '{"Note": "You have exceeded the standard requests per day limit."}',
        );
      });

      expect(
        () => client.fetchEquityQuote(apiKey: 'key', symbol: 'IBM'),
        throwsA(
          isA<AlphaVantageException>().having(
            (e) => e.rateLimited,
            'rateLimited',
            isTrue,
          ),
        ),
      );
    });

    test(
      'a demo-key notice with no rate-limit phrasing is not flagged',
      () async {
        final client = _buildClient((options) async {
          return _jsonResponse(
            '{"Information": "The **demo** API key is for demo purposes only."}',
          );
        });

        expect(
          () => client.fetchEquityQuote(apiKey: 'demo', symbol: 'IBM'),
          throwsA(
            isA<AlphaVantageException>().having(
              (e) => e.rateLimited,
              'rateLimited',
              isFalse,
            ),
          ),
        );
      },
    );

    test('a network failure wraps into an AlphaVantageException', () async {
      final client = _buildClient((options) async {
        throw DioException(
          requestOptions: options,
          message: 'Connection refused',
        );
      });

      expect(
        () => client.fetchEquityQuote(apiKey: 'key', symbol: 'IBM'),
        throwsA(isA<AlphaVantageException>()),
      );
    });
  });
}

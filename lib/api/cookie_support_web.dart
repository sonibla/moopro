import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureCookieHandling(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter(withCredentials: true);
}

typedef SessionCookies = ({String access, String refresh});

Future<SessionCookies?> readSessionCookies(Dio dio) async => null;

Future<void> seedSessionCookies(Dio dio, SessionCookies cookies) async {}

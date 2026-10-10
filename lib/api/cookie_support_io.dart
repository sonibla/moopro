import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

final _jars = Expando<CookieJar>();

typedef SessionCookies = ({String access, String refresh});

void configureCookieHandling(Dio dio) {
  final jar = CookieJar();
  _jars[dio] = jar;
  dio.interceptors.add(CookieManager(jar));
}

Future<SessionCookies?> readSessionCookies(Dio dio) async {
  final jar = _jars[dio];
  if (jar == null) return null;
  final base = Uri.parse(dio.options.baseUrl);
  final access = (await jar.loadForRequest(
    base,
  )).where((c) => c.name == 'access_token').firstOrNull;
  final refresh = (await jar.loadForRequest(
    base.resolve('/refresh'),
  )).where((c) => c.name == 'refresh_token').firstOrNull;
  if (access == null || refresh == null) return null;
  return (access: access.value, refresh: refresh.value);
}

Future<void> seedSessionCookies(Dio dio, SessionCookies cookies) async {
  final jar = _jars[dio];
  if (jar == null) return;
  final uri = Uri.parse(dio.options.baseUrl);
  final secure = uri.scheme == 'https';
  Cookie cookie(String name, String value, String path) => Cookie(name, value)
    ..path = path
    ..httpOnly = true
    ..secure = secure;
  await jar.saveFromResponse(uri, [
    cookie('access_token', cookies.access, '/'),
    cookie('refresh_token', cookies.refresh, '/refresh'),
  ]);
}

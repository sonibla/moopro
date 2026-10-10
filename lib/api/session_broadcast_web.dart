import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'token_store.dart';

Stream<void> watchTokenStoreChangedElsewhere() {
  late final StreamController<void> controller;
  JSFunction? jsListener;

  void onStorage(web.Event event) {
    if (!event.isA<web.StorageEvent>()) return;
    final key = (event as web.StorageEvent).key;
    if (key == null) return;
    bool isTokenKey(String base) =>
        key.endsWith('.$base') || key.contains('.$base:');
    if (isTokenKey(TokenStore.accessTokenKey) ||
        isTokenKey(TokenStore.refreshTokenKey)) {
      controller.add(null);
    }
  }

  controller = StreamController<void>.broadcast(
    onListen: () {
      jsListener = onStorage.toJS;
      web.window.addEventListener('storage', jsListener);
    },
    onCancel: () {
      final listener = jsListener;
      if (listener != null) {
        web.window.removeEventListener('storage', listener);
        jsListener = null;
      }
    },
  );
  return controller.stream;
}

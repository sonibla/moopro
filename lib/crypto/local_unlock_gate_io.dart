import 'dart:io';

import 'package:local_auth/local_auth.dart';

bool get localUnlockHasRealGate =>
    Platform.isAndroid ||
    Platform.isIOS ||
    Platform.isMacOS ||
    Platform.isWindows;

Future<bool> authenticateForLocalUnlock({required String reason}) async {
  if (!localUnlockHasRealGate) return true;
  try {
    return await LocalAuthentication().authenticate(
      localizedReason: reason,
      biometricOnly: false,
    );
  } on Exception {
    return false;
  }
}

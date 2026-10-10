import 'dart:math';

String generateRecordId() {
  final rng = Random.secure();
  final high = rng.nextInt(0x100000000);
  final low = rng.nextInt(0x100000000);
  return high.toRadixString(16).padLeft(8, '0') +
      low.toRadixString(16).padLeft(8, '0');
}

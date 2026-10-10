import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/widgets/bank_icons.dart';

void main() {
  test('every registry entry has an SVG file and vice versa', () {
    final files = Directory('assets/bank_icons')
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.svg'))
        .map((n) => n.substring(0, n.length - 4))
        .toSet();
    expect(
      bankIconRegistry.keys.toSet(),
      files,
      reason:
          'registry and assets/bank_icons/*.svg must match — see '
          'assets/bank_icons/README.md',
    );
  });

  test('ids are well-formed, match their map key, and are sorted', () {
    final ids = bankIconRegistry.keys.toList();
    for (final e in bankIconRegistry.entries) {
      expect(e.value.id, e.key);
      expect(RegExp(r'^[a-z0-9_]+$').hasMatch(e.key), isTrue);
      expect(e.value.aliases.every((a) => a == a.toLowerCase()), isTrue);
    }
    expect(ids, [...ids]..sort());
  });
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final b in Brightness.values) {
    test('onPrimary on primary meets WCAG AA (4.5:1) in $b', () {
      final scheme = (b == Brightness.dark ? AppTheme.dark() : AppTheme.light())
          .colorScheme;
      expect(
        _contrast(scheme.primary, scheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('accent text on paper meets WCAG AA (4.5:1) in $b', () {
      expect(
        _contrast(AppTheme.accent(b), AppTheme.paper(b)),
        greaterThanOrEqualTo(4.5),
      );
    });
  }
}

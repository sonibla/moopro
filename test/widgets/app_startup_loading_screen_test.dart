import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/theme/app_theme.dart';
import 'package:moopro/widgets/app_startup_loading_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('uses themed 108px ring in $brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark()
              : AppTheme.light(),
          home: const AppStartupLoadingScaffold(),
        ),
      );

      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      expect(indicator.color, AppTheme.accent(brightness));
      expect(indicator.backgroundColor, AppTheme.accentSoft(brightness));
      expect(indicator.strokeWidth, 8);
      expect(tester.getSize(find.byType(SizedBox).last), const Size(108, 108));
    });
  }
}

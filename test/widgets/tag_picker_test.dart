import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/theme/app_theme.dart';
import 'package:moopro/widgets/tag_picker.dart';

void main() {
  const counts = {'Japan trip': 5, 'Food': 9, 'Reimbursable': 2, 'Fuel': 9};

  Set<String>? result;
  var resolved = false;

  Future<void> pump(
    WidgetTester tester, {
    Set<String> selected = const {},
    Map<String, int> tagCounts = counts,
    double width = 1400,
  }) async {
    result = null;
    resolved = false;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showTagPicker(
                  context: context,
                  tagCounts: tagCounts,
                  selected: selected,
                );
                resolved = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('filterTagsByQuery', () {
    test('sorts by usage count desc, then alphabetically', () {
      expect(filterTagsByQuery(counts, ''), [
        'Food',
        'Fuel',
        'Japan trip',
        'Reimbursable',
      ]);
    });

    test('matches case-insensitively on substrings', () {
      expect(filterTagsByQuery(counts, 'JAP'), ['Japan trip']);
      expect(filterTagsByQuery(counts, ' jap '), ['Japan trip']);
      expect(filterTagsByQuery(counts, 'xyz'), isEmpty);
      expect(filterTagsByQuery(counts, 'u'), ['Fuel', 'Reimbursable']);
    });
  });

  group('showTagPicker', () {
    testWidgets('lists tags most-used first with their counts', (tester) async {
      await pump(tester);

      final food = tester.getTopLeft(find.text('Food')).dy;
      final japan = tester.getTopLeft(find.text('Japan trip')).dy;
      final reimb = tester.getTopLeft(find.text('Reimbursable')).dy;
      expect(food, lessThan(japan));
      expect(japan, lessThan(reimb));
      expect(find.text('9'), findsNWidgets(2));
      expect(
        find.text('Showing transactions with all selected tags'),
        findsOneWidget,
      );
    });

    testWidgets('searching narrows the list and shows an empty state', (
      tester,
    ) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'jap');
      await tester.pump();
      expect(find.text('Japan trip'), findsOneWidget);
      expect(find.text('Food'), findsNothing);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No matches.'), findsOneWidget);
    });

    testWidgets('multi-selects across searches and Done returns the set', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'jap');
      await tester.pump();
      await tester.tap(find.text('Japan trip'));
      await tester.pump();

      expect(find.byType(InputChip), findsNWidgets(2));

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, {'Food', 'Japan trip'});
    });

    testWidgets('the chip × deselects a tag', (tester) async {
      await pump(tester, selected: const {'Food', 'Fuel'});
      expect(find.byType(InputChip), findsNWidgets(2));

      final chip = tester.widget<InputChip>(
        find.widgetWithText(InputChip, 'Food'),
      );
      chip.onDeleted!();
      await tester.pump();
      expect(find.byType(InputChip), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, {'Fuel'});
    });

    testWidgets('Clear empties the selection', (tester) async {
      await pump(tester, selected: const {'Food'});

      await tester.tap(find.text('Clear'));
      await tester.pump();
      expect(find.byType(InputChip), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
    });

    testWidgets('a selected tag no longer in use can still be removed', (
      tester,
    ) async {
      await pump(tester, selected: const {'Gone'});

      expect(find.widgetWithText(InputChip, 'Gone'), findsOneWidget);
      tester
          .widget<InputChip>(find.widgetWithText(InputChip, 'Gone'))
          .onDeleted!();
      await tester.pump();
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('closing discards changes and returns null', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(result, isNull);
    });

    testWidgets('is a dialog on desktop and a bottom sheet on mobile', (
      tester,
    ) async {
      await pump(tester);
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      await pump(tester, width: 500);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });
  });
}

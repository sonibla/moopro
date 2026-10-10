import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_filter.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/theme/app_theme.dart';
import 'package:moopro/widgets/transaction_filter_bar.dart';

void main() {
  final containers = [
    const ldb.Container(
      id: externalHolderContainerId,
      name: 'External',
      containerType: 'holder',
      deleted: false,
    ),
    const ldb.Container(
      id: externalBudgetContainerId,
      name: 'External',
      containerType: 'budget',
      deleted: false,
    ),
    const ldb.Container(
      id: 'bank1',
      name: 'Bank',
      containerType: 'holder',
      deleted: false,
    ),
  ];

  const assets = [
    ldb.Asset(
      id: 'eur',
      kind: 'fiat',
      symbol: 'EUR',
      name: 'Euro',
      deleted: false,
    ),
  ];

  TransactionFilter? lastChanged;

  Future<void> pump(
    WidgetTester tester, {
    TransactionFilter filter = TransactionFilter.empty,
    Map<String, int> tagCounts = const {},
  }) async {
    lastChanged = null;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          containersStreamProvider.overrideWith(
            (ref) => Stream.value(containers),
          ),
          transactionsStreamProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: TransactionFilterBar(
              filter: filter,
              onChanged: (f) => lastChanged = f,
              containers: containers,
              assets: assets,
              tagCounts: tagCounts,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('mobile (<900px)', () {
    testWidgets('the "more filters" container picker never offers the external '
        'sentinels — only real user-created containers', (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, 'Container'),
      );
      await tester.pumpAndSettle();

      expect(find.text('External'), findsNothing);
      expect(find.text('Bank'), findsWidgets);
    });

    testWidgets('kind filtering now lives inside the "more filters" sheet, '
        'each with that kind\'s icon', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.arrow_circle_down_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_circle_down_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_circle_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.account_balance), findsOneWidget);
      expect(find.byIcon(Icons.pie_chart), findsOneWidget);

      await tester.tap(find.text('Income'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(lastChanged?.kinds, equals({TransactionKind.income}));
    });

    testWidgets('tapping the search icon reveals an inline field that '
        'reports typed text as the search query', (tester) async {
      await pump(tester);

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byIcon(Icons.search));
      await tester.pump();

      expect(find.byType(TextField), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'sushi');

      expect(lastChanged?.searchQuery, equals('sushi'));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });
    testWidgets('the sheet\'s date scope is a segmented choice; the custom '
        'range field appears only for Custom and is padded like the '
        'dropdowns', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(SegmentedButton<DateScope>, 'Future'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('customDateRangeField')), findsNothing);

      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('customDateRangeField'));
      expect(field, findsOneWidget);
      expect(find.text('Select dates'), findsOneWidget);

      final fieldRect = tester.getRect(field);
      expect(
        tester.getRect(find.byIcon(Icons.date_range)).right,
        lessThan(fieldRect.right - 4),
      );
      expect(
        tester.getRect(find.text('Select dates')).left,
        greaterThan(fieldRect.left + 4),
      );
    });

    testWidgets('applying "Future" reports that scope with no range', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Future'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(lastChanged?.dateScope, DateScope.future);
      expect(lastChanged?.dateRange, isNull);
    });

    testWidgets('the more-filters sheet has a Tags field that opens the '
        'picker and applies the multi-selection', (tester) async {
      await pump(tester, tagCounts: const {'Japan trip': 3, 'Food': 2});

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      expect(find.text('Any'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('tagsField')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Japan trip'));
      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('2 tags'), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(lastChanged?.tags, {'Japan trip', 'Food'});
    });

    testWidgets('an active tag filter counts on the tune badge and shows no '
        'loose chip', (tester) async {
      await pump(
        tester,
        tagCounts: const {'Japan trip': 3},
        filter: const TransactionFilter(tags: {'Japan trip'}),
      );
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('an active date scope counts on the tune badge', (
      tester,
    ) async {
      await pump(
        tester,
        filter: const TransactionFilter(dateScope: DateScope.past),
      );
      expect(find.widgetWithText(Badge, '1'), findsOneWidget);
    });
  });

  group('desktop (>900px)', () {
    Future<void> pumpWide(
      WidgetTester tester, {
      TransactionFilter filter = TransactionFilter.empty,
      Map<String, int> tagCounts = const {},
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester, filter: filter, tagCounts: tagCounts);
    }

    testWidgets('shows an inline search field and one pill per filter, no '
        'tune/select icons', (tester) async {
      await pumpWide(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All types'), findsOneWidget);
      expect(find.text('Any dates'), findsOneWidget);
      expect(find.text('All budgets/holders'), findsOneWidget);
      expect(find.text('All assets'), findsOneWidget);
      expect(find.byIcon(Icons.tune), findsNothing);
    });

    testWidgets('the type pill opens a checklist that stays open across '
        'multiple toggles and reports the updated kind set', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text('All types'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Income'));
      await tester.pump();
      expect(lastChanged?.kinds, equals({TransactionKind.income}));

      expect(find.text('Expense'), findsOneWidget);
    });

    testWidgets('the budget/holder pill offers a Budget/Holder choice that '
        'opens the container picker', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text('All budgets/holders'));
      await tester.pumpAndSettle();
      expect(find.text('Holder…'), findsOneWidget);

      await tester.tap(find.text('Holder…'));
      await tester.pumpAndSettle();

      expect(find.text('Filter by holder'), findsOneWidget);
    });

    testWidgets('the asset pill opens the asset picker', (tester) async {
      await pumpWide(tester);

      await tester.tap(find.text('All assets'));
      await tester.pumpAndSettle();

      expect(find.text('Select asset'), findsOneWidget);
    });

    testWidgets('the tag pill only appears when there are tags to filter by', (
      tester,
    ) async {
      await pumpWide(tester);
      expect(find.text('Tags'), findsNothing);

      await pumpWide(tester, tagCounts: const {'Japan trip': 1});
      expect(find.text('Tags'), findsOneWidget);
    });

    testWidgets('the date pill offers Any / Past / Future / Custom and reports '
        'the chosen scope', (tester) async {
      await pumpWide(tester);
      await tester.tap(find.text('Any dates'));
      await tester.pumpAndSettle();

      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Future'), findsOneWidget);
      expect(find.text('Custom range'), findsOneWidget);

      await tester.tap(find.text('Future'));
      await tester.pumpAndSettle();
      expect(lastChanged?.dateScope, DateScope.future);
    });

    testWidgets('a date preset reports a concrete custom range ending today', (
      tester,
    ) async {
      await pumpWide(tester);
      await tester.tap(find.text('Any dates'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Month to date'));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      expect(lastChanged?.dateScope, DateScope.custom);
      expect(lastChanged?.dateRange?.start, DateTime(now.year, now.month));
      expect(
        lastChanged?.dateRange?.end,
        DateTime(now.year, now.month, now.day),
      );
    });

    testWidgets(
      'Custom range opens the picker, and cancelling changes nothing',
      (tester) async {
        await pumpWide(tester);
        await tester.tap(find.text('Any dates'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Custom range'));
        await tester.pumpAndSettle();
        expect(find.byType(DateRangePickerDialog), findsOneWidget);

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
        expect(lastChanged, isNull);
      },
    );

    testWidgets(
      'an active scope labels the pill and its × resets to all dates',
      (tester) async {
        await pumpWide(
          tester,
          filter: const TransactionFilter(dateScope: DateScope.past),
        );
        expect(find.text('Past'), findsOneWidget);
        expect(find.text('Any dates'), findsNothing);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();
        expect(lastChanged?.dateScope, DateScope.all);
      },
    );

    testWidgets('the tag pill reads "Tags", the tag name, or "N tags"', (
      tester,
    ) async {
      const counts = {'Japan trip': 3, 'Food': 2};
      await pumpWide(tester, tagCounts: counts);
      expect(find.text('Tags'), findsOneWidget);

      await pumpWide(
        tester,
        tagCounts: counts,
        filter: const TransactionFilter(tags: {'Japan trip'}),
      );
      expect(find.text('Japan trip'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);

      await pumpWide(
        tester,
        tagCounts: counts,
        filter: const TransactionFilter(tags: {'Japan trip', 'Food'}),
      );
      expect(find.text('2 tags'), findsOneWidget);
    });

    testWidgets('the tag pill\'s × clears every selected tag', (tester) async {
      await pumpWide(
        tester,
        tagCounts: const {'Japan trip': 3, 'Food': 2},
        filter: const TransactionFilter(tags: {'Japan trip', 'Food'}),
      );

      await tester.tap(
        find.descendant(
          of: find
              .ancestor(of: find.text('2 tags'), matching: find.byType(InkWell))
              .first,
          matching: find.byIcon(Icons.close),
        ),
      );
      await tester.pump();

      expect(lastChanged?.tags, isEmpty);
    });

    testWidgets('the tag pill opens the picker and Done reports the '
        'multi-selection', (tester) async {
      await pumpWide(tester, tagCounts: const {'Japan trip': 3, 'Food': 2});

      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      expect(find.text('Filter by tags'), findsOneWidget);

      await tester.tap(find.text('Japan trip'));
      await tester.tap(find.text('Food'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(lastChanged?.tags, {'Japan trip', 'Food'});
    });

    testWidgets('dismissing the picker without Done leaves the filter '
        'untouched', (tester) async {
      await pumpWide(tester, tagCounts: const {'Japan trip': 3});

      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Japan trip'));
      await tester.pump();
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();

      expect(lastChanged, isNull);
    });
  });
}

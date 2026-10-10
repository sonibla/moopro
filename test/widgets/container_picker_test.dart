import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/container_picker.dart';
import 'package:moopro/domain/calendar_date.dart';

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
      id: 'h1',
      name: 'Boursorama',
      containerType: 'holder',
      deleted: false,
    ),
    const ldb.Container(
      id: 'h2',
      name: 'Revolut',
      containerType: 'holder',
      deleted: false,
    ),
    const ldb.Container(
      id: 'h3',
      name: 'Coinbase',
      containerType: 'holder',
      deleted: false,
    ),
    const ldb.Container(
      id: 'b1',
      name: 'Spendings',
      containerType: 'budget',
      deleted: false,
    ),
    const ldb.Container(
      id: 'b2',
      name: 'Restaurants',
      containerType: 'budget',
      parentId: 'b1',
      deleted: false,
    ),
  ];

  ldb.Transaction incomeTx(
    String id, {
    required String holderId,
    required DateTime postedAt,
  }) => ldb.Transaction(
    id: id,
    postedAt: postedAt,
    effectiveDate: CalendarDate.fromDateTime(postedAt),
    kind: 'income',
    legOutContainerId: externalHolderContainerId,
    legOutAssetId: 'eur',
    legOutQuantity: '1',
    legInContainerId: holderId,
    legInAssetId: 'eur',
    legInQuantity: '1',
    budgetLegOutContainerId: externalBudgetContainerId,
    budgetLegOutAssetId: 'eur',
    budgetLegOutQuantity: '1',
    budgetLegInContainerId: 'b1',
    budgetLegInAssetId: 'eur',
    budgetLegInQuantity: '1',
    tags: '[]',
    manualOrderRank: 0,
    deleted: false,
  );

  Widget harness({
    String? initialValue,
    ContainerType type = ContainerType.holder,
    bool allowNone = false,
    List<ldb.Transaction> transactions = const [],
    List<ldb.Container>? containersOverride,
  }) {
    return ProviderScope(
      overrides: [
        containersStreamProvider.overrideWith(
          (ref) => Stream.value(containersOverride ?? containers),
        ),
        transactionsStreamProvider.overrideWith(
          (ref) => Stream.value(transactions),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              String? value = initialValue;
              return ContainerPickerField(
                label: 'Holder',
                type: type,
                value: value,
                allowNone: allowNone,
                required: !allowNone,
                onChanged: (v) => setState(() => value = v),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets(
    'shows a placeholder when nothing is selected, breadcrumb when it is',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      expect(find.text('Select...'), findsOneWidget);

      await tester.pumpWidget(
        harness(initialValue: 'b2', type: ContainerType.budget),
      );
      await tester.pumpAndSettle();
      expect(find.text('Spendings › Restaurants'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the field opens a picker excluding the external sentinel',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select...'));
      await tester.pumpAndSettle();

      expect(find.text('External'), findsNothing);
      expect(find.text('Boursorama'), findsOneWidget);
      expect(find.text('Revolut'), findsOneWidget);
      expect(find.text('Coinbase'), findsOneWidget);
    },
  );

  testWidgets('searching filters the list and shows the breadcrumb path', (
    tester,
  ) async {
    await tester.pumpWidget(harness(type: ContainerType.budget));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select...'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'resta');
    await tester.pumpAndSettle();

    expect(find.text('Spendings › Restaurants'), findsOneWidget);
    expect(find.text('Spendings'), findsNothing);
  });

  testWidgets('tapping a row selects it and closes the picker', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select...'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Revolut'));
    await tester.pumpAndSettle();

    expect(find.text('Revolut'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets(
    'shows a "Recent" row derived from transactions, tapping it selects',
    (tester) async {
      final txs = [
        incomeTx('t1', holderId: 'h1', postedAt: DateTime(2026, 1, 1)),
        incomeTx('t2', holderId: 'h3', postedAt: DateTime(2026, 1, 5)),
      ];
      await tester.pumpWidget(harness(transactions: txs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select...'));
      await tester.pumpAndSettle();

      expect(find.text('RECENT'), findsOneWidget);
      final coinbaseChip = find.widgetWithText(ActionChip, 'Coinbase');
      expect(coinbaseChip, findsOneWidget);

      await tester.tap(coinbaseChip);
      await tester.pumpAndSettle();
      expect(find.text('Coinbase'), findsOneWidget);
    },
  );

  testWidgets('a Recent chip and the list rows show the container\'s icon', (
    tester,
  ) async {
    final withIcons = [
      for (final c in containers)
        if (c.id == 'h3')
          ldb.Container(
            id: 'h3',
            name: 'Coinbase',
            containerType: 'holder',
            icon: 'fa:bitcoin',
            deleted: false,
          )
        else
          c,
    ];
    final txs = [
      incomeTx('t2', holderId: 'h3', postedAt: DateTime(2026, 1, 5)),
    ];
    await tester.pumpWidget(
      harness(transactions: txs, containersOverride: withIcons),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select...'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(ActionChip),
        matching: find.byType(FaIcon),
      ),
      findsOneWidget,
    );
    expect(find.byType(FaIcon), findsNWidgets(2));
  });

  testWidgets('allowNone offers a None row that clears the value', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(initialValue: 'h1', allowNone: true, type: ContainerType.holder),
    );
    await tester.pumpAndSettle();
    expect(find.text('Boursorama'), findsOneWidget);

    await tester.tap(find.text('Boursorama'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('None (top-level)'));
    await tester.pumpAndSettle();

    expect(find.text('Select...'), findsOneWidget);
  });

  testWidgets(
    'dismissing the picker without a choice leaves the value unchanged',
    (tester) async {
      await tester.pumpWidget(harness(initialValue: 'h1'));
      await tester.pumpAndSettle();
      expect(find.text('Boursorama'), findsOneWidget);

      await tester.tap(find.text('Boursorama'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Boursorama'), findsOneWidget);
    },
  );

  testWidgets(
    'opens as a dialog instead of a bottom sheet above the 900px breakpoint',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select...'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}

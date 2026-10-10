import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/tag_input.dart';
import 'package:moopro/domain/calendar_date.dart';

ldb.Transaction _tx(String id, {required List<String> tags}) => ldb.Transaction(
  id: id,
  postedAt: DateTime(2026, 1, 1),
  effectiveDate: CalendarDate(2026, 1, 1),
  kind: 'holderTransfer',
  legOutContainerId: 'h1',
  legOutAssetId: 'eur',
  legOutQuantity: '1',
  legInContainerId: 'h2',
  legInAssetId: 'eur',
  legInQuantity: '1',
  tags: encodeTagsColumn(tags),
  manualOrderRank: 0,
  deleted: false,
);

void main() {
  Widget harness({
    List<String> tags = const [],
    List<ldb.Transaction> transactions = const [],
    ValueChanged<List<String>>? onChanged,
  }) {
    return ProviderScope(
      overrides: [
        transactionsStreamProvider.overrideWith(
          (ref) => Stream.value(transactions),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: TagInput(tags: tags, onChanged: onChanged ?? (_) {}),
        ),
      ),
    );
  }

  testWidgets('shows an existing pill per tag', (tester) async {
    await tester.pumpWidget(
      harness(tags: const ['Japan trip', 'Reimbursable']),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Japan trip'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Reimbursable'), findsOneWidget);
  });

  testWidgets('deleting a pill removes just that tag', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(
        tags: const ['Japan trip', 'Reimbursable'],
        onChanged: (v) => result = v,
      ),
    );
    await tester.pumpAndSettle();

    final chip = tester.widget<InputChip>(
      find.widgetWithText(InputChip, 'Japan trip'),
    );
    chip.onDeleted!();
    await tester.pumpAndSettle();

    expect(result, equals(['Reimbursable']));
  });

  testWidgets('typing a new tag and submitting adds it', (tester) async {
    List<String>? result;
    await tester.pumpWidget(harness(onChanged: (v) => result = v));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, equals(['Groceries']));
  });

  testWidgets('does not add a duplicate of an already-selected tag', (
    tester,
  ) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(tags: const ['Groceries'], onChanged: (v) => result = v),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Groceries');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('suggests existing tags from other transactions, excluding '
      'already-selected ones, and tapping one commits it', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      harness(
        tags: const ['Groceries'],
        transactions: [
          _tx('t1', tags: const ['Groceries', 'Japan trip']),
          _tx('t2', tags: const ['Paris trip']),
        ],
        onChanged: (v) => result = v,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add tag'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ActionChip, 'Groceries'), findsNothing);
    expect(find.widgetWithText(ActionChip, 'Japan trip'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'Paris trip'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Japan trip'));
    await tester.pumpAndSettle();

    expect(result, equals(['Groceries', 'Japan trip']));
  });
}

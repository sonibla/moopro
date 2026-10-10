import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/mass_edit_tags_dialog.dart';

typedef _Result = ({List<String> add, List<String> remove});

Future<void> _open(
  WidgetTester tester, {
  List<String> present = const ['food', 'trip'],
  void Function(_Result?)? onResult,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transactionsStreamProvider.overrideWith(
          (ref) => Stream.value(const <ldb.Transaction>[]),
        ),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final r = await showMassEditTagsDialog(
                context,
                count: 3,
                presentTags: present,
              );
              onResult?.call(r);
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

void main() {
  testWidgets('Apply is disabled until something is chosen', (tester) async {
    await _open(tester);
    FilledButton apply() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'));
    expect(apply().onPressed, isNull);
    await tester.tap(find.widgetWithText(FilterChip, 'food'));
    await tester.pump();
    expect(apply().onPressed, isNotNull);
  });

  testWidgets('removal is limited to the tags present on the selection', (
    tester,
  ) async {
    await _open(tester, present: ['food']);
    expect(find.widgetWithText(FilterChip, 'food'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'trip'), findsNothing);
  });

  testWidgets('shows a note when no selected transaction has tags', (
    tester,
  ) async {
    await _open(tester, present: const []);
    expect(
      find.text('None of the selected transactions have tags.'),
      findsOneWidget,
    );
  });

  testWidgets('a brand-new tag can be typed and is returned in add, along '
      'with removals', (tester) async {
    _Result? result;
    await _open(tester, onResult: (r) => result = r);

    await tester.tap(find.text('Add tag'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'brand new');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'food'));
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.add, ['brand new']);
    expect(result!.remove, ['food']);
  });

  testWidgets('Cancel returns null', (tester) async {
    _Result? result = (add: ['x'], remove: []);
    await _open(tester, onResult: (r) => result = r);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/container_form_dialog.dart';
import 'package:moopro/widgets/container_picker.dart';

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
      id: 'budget1',
      name: 'Groceries',
      containerType: 'budget',
      deleted: false,
    ),
  ];

  Future<void> pump(WidgetTester tester) async {
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
        child: const MaterialApp(home: Scaffold(body: ContainerFormDialog())),
      ),
    );
    await tester.pump();
  }

  Future<void> pumpDialog(WidgetTester tester) async {
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
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const ContainerFormDialog(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the parent-budget picker never offers the external sentinel — only '
    'real user-created budgets',
    (tester) async {
      await pump(tester);

      await tester.tap(find.text('Budget'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ContainerPickerField));
      await tester.pumpAndSettle();

      expect(find.text('External'), findsNothing);
      expect(find.text('Groceries'), findsWidgets);
    },
  );

  group('unsaved changes confirmation', () {
    testWidgets(
      'tapping outside the dialog barrier with unsaved changes prompts '
      'instead of closing immediately',
      (tester) async {
        await pumpDialog(tester);

        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Savings',
        );
        await tester.pumpAndSettle();

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.text('New container'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets(
      "'Keep editing' dismisses the prompt and leaves the form open with "
      'the typed text intact',
      (tester) async {
        await pumpDialog(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Savings',
        );
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Keep editing'));
        await tester.pumpAndSettle();

        expect(find.text('Discard changes?'), findsNothing);
        expect(find.text('Savings'), findsOneWidget);
      },
    );

    testWidgets("'Discard' closes both the prompt and the form", (
      tester,
    ) async {
      await pumpDialog(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Savings');
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Discard'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New container'), findsNothing);
    });

    testWidgets(
      "the Cancel button also prompts (an explicit button's onPressed isn't "
      'gated by PopScope the way a barrier tap/Escape is)',
      (tester) async {
        await pumpDialog(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Name'),
          'Savings',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('New container'), findsOneWidget);
        expect(find.text('Discard changes?'), findsOneWidget);
      },
    );

    testWidgets('closes immediately with no unsaved changes', (tester) async {
      await pumpDialog(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('New container'), findsNothing);
    });
  });

  group('icon field', () {
    testWidgets('starts as None; picking an icon shows it and makes the form '
        'dirty (Cancel then prompts)', (tester) async {
      await pumpDialog(tester);
      expect(find.byType(FaIcon), findsNothing);
      expect(find.text('None'), findsOneWidget);

      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      expect(find.text('Choose icon'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search icons'),
        'real estate',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Solid House').first);
      await tester.pumpAndSettle();

      expect(find.text('Choose icon'), findsNothing);
      expect(find.byType(FaIcon), findsOneWidget);
      expect(find.text('None'), findsNothing);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
    });

    testWidgets('dismissing the picker leaves the icon unchanged and the '
        'form clean', (tester) async {
      await pumpDialog(tester);
      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      expect(find.text('None'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsNothing);
    });

    testWidgets('editing a container with an icon shows it; "No icon" '
        'clears it', (tester) async {
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
          child: const MaterialApp(
            home: Scaffold(
              body: ContainerFormDialog(
                existing: ldb.Container(
                  id: 'h1',
                  name: 'Bank',
                  containerType: 'holder',
                  icon: 'fa:solidHouse',
                  deleted: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FaIcon), findsOneWidget);

      await tester.tap(find.text('Icon'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('No icon'));
      await tester.pumpAndSettle();

      expect(find.byType(FaIcon), findsNothing);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('an unresolvable stored icon shows as None', (tester) async {
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
          child: const MaterialApp(
            home: Scaffold(
              body: ContainerFormDialog(
                existing: ldb.Container(
                  id: 'h1',
                  name: 'Bank',
                  containerType: 'holder',
                  icon: 'fa:removedInFutureVersion',
                  deleted: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(FaIcon), findsNothing);
      expect(find.text('None'), findsOneWidget);
    });
  });
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_kind_style.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/amount_text.dart';
import 'package:moopro/widgets/transaction_tile.dart';
import 'package:moopro/domain/calendar_date.dart';

const _eur = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
);
const _btc = Asset(
  id: 'btc',
  kind: AssetKind.crypto,
  symbol: 'BTC',
  name: 'Bitcoin',
);

Widget _wrap(Widget child) => ProviderScope(
  overrides: [
    recordSyncStatusesProvider.overrideWith((ref) => Stream.value(const {})),
  ],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  group('TransactionTile', () {
    testWidgets(
      'shows the kind icon avatar (not a checkbox) outside selection mode',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TransactionTile(
              date: CalendarDate(2026, 1, 1),
              title: 'Test',
              displayQuantity: Decimal.parse('10'),
              displayAsset: _eur,
              sign: AmountSign.neutral,
              kind: TransactionKind.holderTransfer,
              recordId: 'tx1',
            ),
          ),
        );

        expect(
          find.byIcon(
            TransactionKindStyle.iconOf(TransactionKind.holderTransfer),
          ),
          findsOneWidget,
        );
        expect(find.byType(Checkbox), findsNothing);
      },
    );

    testWidgets('swaps to a checkbox and reports taps via onSelectedChanged '
        'in selection mode', (tester) async {
      bool? changedTo;
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            selectionMode: true,
            selected: false,
            onSelectedChanged: (v) => changedTo = v,
          ),
        ),
      );

      expect(find.byType(Checkbox), findsOneWidget);
      expect(
        find.byIcon(
          TransactionKindStyle.iconOf(TransactionKind.holderTransfer),
        ),
        findsNothing,
      );

      await tester.tap(find.byType(ListTile));
      expect(changedTo, isTrue);
    });

    testWidgets(
      'shows a "posted" hint only when postedAtIfDifferentDay is set',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TransactionTile(
              date: CalendarDate(2026, 1, 10),
              title: 'Test',
              displayQuantity: Decimal.parse('10'),
              displayAsset: _eur,
              sign: AmountSign.neutral,
              kind: TransactionKind.holderTransfer,
              recordId: 'tx1',
              showDateInline: false,
              postedAtIfDifferentDay: DateTime(2026, 1, 8),
            ),
          ),
        );

        expect(find.textContaining('posted 2026-01-08'), findsOneWidget);
      },
    );

    testWidgets('has no subtitle at all when there is no note, no inline date, '
        'and no posted-date hint', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 10),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            showDateInline: false,
          ),
        ),
      );

      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.subtitle, isNull);
    });

    testWidgets('caps title and subtitle to a single line even with a long '
        'note (fixed-height rows for scroll performance at large lists)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title:
                'A very long transaction title that would otherwise wrap '
                'onto a second line if left unconstrained',
            note:
                'A very long note that would otherwise wrap onto a second or '
                'even third line if left unconstrained, making row heights '
                'unpredictable',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            showDateInline: true,
          ),
        ),
      );

      final titles = tester.widgetList<Text>(
        find.descendant(of: find.byType(ListTile), matching: find.byType(Text)),
      );
      final title = titles.firstWhere(
        (t) => t.data!.startsWith('A very long transaction'),
      );
      final subtitle = titles.firstWhere(
        (t) => t.data!.contains('A very long note'),
      );
      expect(title.maxLines, 1);
      expect(subtitle.maxLines, 1);
    });

    testWidgets('shows the reorder affordance only for a cluster size > 1', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            reorderClusterSize: 1,
          ),
        ),
      );
      expect(find.byIcon(Icons.unfold_more), findsNothing);

      bool tapped = false;
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            reorderClusterSize: 3,
            onReorderCluster: () => tapped = true,
          ),
        ),
      );
      expect(find.byIcon(Icons.unfold_more), findsOneWidget);
      await tester.tap(find.byIcon(Icons.unfold_more));
      expect(tapped, isTrue);
    });

    testWidgets('shows no tag row and the base height when there are no tags', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
          ),
        ),
      );

      expect(find.byType(Chip), findsNothing);
      expect(TransactionTile.heightFor(const []), TransactionTile.height);
    });

    testWidgets('shows a pill per tag and a taller fixed height when tagged', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Test',
            displayQuantity: Decimal.parse('10'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.holderTransfer,
            recordId: 'tx1',
            tags: const ['Japan trip', 'Reimbursable'],
          ),
        ),
      );

      expect(find.widgetWithText(Chip, 'Japan trip'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'Reimbursable'), findsOneWidget);
      expect(
        TransactionTile.heightFor(const ['Japan trip']),
        greaterThan(TransactionTile.height),
      );

      final box = tester.getSize(find.byType(TransactionTile));
      expect(
        box.height,
        TransactionTile.heightFor(const ['Japan trip', 'Reimbursable']),
      );
    });

    testWidgets('a trade with a resolved "get" side renders the give→get '
        'pair via TradeAmountText, not a single-sided AmountText', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Bought BTC',
            displayQuantity: Decimal.parse('500'),
            displayAsset: _eur,
            tradeQuantityIn: Decimal.parse('0.0071'),
            tradeAssetIn: _btc,
            sign: AmountSign.neutral,
            kind: TransactionKind.trade,
            recordId: 'tx1',
          ),
        ),
      );

      expect(find.byType(TradeAmountText), findsOneWidget);
      expect(find.byType(AmountText), findsNothing);
      expect(
        TransactionTile.heightFor(const [], isTwoAssetTrade: true),
        greaterThan(TransactionTile.height),
      );
    });

    testWidgets('a trade with no resolved "get" side falls back to the '
        'plain single-sided AmountText rather than crashing', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TransactionTile(
            date: CalendarDate(2026, 1, 1),
            title: 'Bought BTC',
            displayQuantity: Decimal.parse('500'),
            displayAsset: _eur,
            sign: AmountSign.neutral,
            kind: TransactionKind.trade,
            recordId: 'tx1',
          ),
        ),
      );

      expect(find.byType(AmountText), findsOneWidget);
      expect(find.byType(TradeAmountText), findsNothing);
    });

    group('make recurring button', () {
      Widget tile({
        VoidCallback? onMakeRecurring,
        TransactionKind kind = TransactionKind.expense,
      }) => _wrap(
        TransactionTile(
          date: CalendarDate(2026, 1, 1),
          title: 'Test',
          displayQuantity: Decimal.parse('10'),
          displayAsset: _eur,
          sign: AmountSign.negative,
          kind: kind,
          recordId: 'tx1',
          onMakeRecurring: onMakeRecurring,
        ),
      );

      testWidgets('invokes the callback when tapped', (tester) async {
        var taps = 0;
        await tester.pumpWidget(tile(onMakeRecurring: () => taps++));

        await tester.tap(find.byTooltip('Make recurring'));
        expect(taps, 1);
      });

      testWidgets('is hidden when no callback is given', (tester) async {
        await tester.pumpWidget(tile());

        expect(find.byTooltip('Make recurring'), findsNothing);
      });
    });
  });
}

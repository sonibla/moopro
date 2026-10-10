import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/selection_stats.dart';
import 'package:moopro/widgets/selection_stats_dialog.dart';

const _eur = Asset(id: 'eur', kind: AssetKind.fiat, symbol: '€', name: 'Euro');
const _btc = Asset(
  id: 'btc',
  kind: AssetKind.crypto,
  symbol: 'BTC',
  name: 'Bitcoin',
);

Future<void> _open(WidgetTester tester, SelectionStats stats) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showSelectionStatsDialog(context, stats),
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
  testWidgets('shows count, per-kind sums, net, and date range', (
    tester,
  ) async {
    await _open(
      tester,
      SelectionStats(
        count: 3,
        byKind: [
          KindStats(
            kind: TransactionKind.income,
            count: 2,
            totals: [AssetTotal(_eur, Decimal.parse('150'))],
          ),
          KindStats(
            kind: TransactionKind.trade,
            count: 1,
            totals: [AssetTotal(_eur, Decimal.parse('500'))],
            totalsIn: [AssetTotal(_btc, Decimal.parse('0.01'))],
          ),
        ],
        net: [AssetTotal(_eur, Decimal.parse('-20'))],
        firstDate: CalendarDate(2026, 1, 1),
        lastDate: CalendarDate(2026, 2, 1),
      ),
    );
    expect(find.text('3 transactions'), findsOneWidget);
    expect(find.text('2026-01-01 → 2026-02-01'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('150.00 €'), findsOneWidget);
    expect(find.text('0.01000000 BTC'), findsOneWidget);
    expect(find.text('−20.00 €'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('3 transactions'), findsNothing);
  });

  testWidgets('single transaction: singular title, one-day range, no net', (
    tester,
  ) async {
    await _open(
      tester,
      SelectionStats(
        count: 1,
        byKind: [
          KindStats(
            kind: TransactionKind.holderTransfer,
            count: 1,
            totals: [AssetTotal(_eur, Decimal.parse('5'))],
          ),
        ],
        net: const [],
        firstDate: CalendarDate(2026, 1, 1),
        lastDate: CalendarDate(2026, 1, 1),
      ),
    );
    expect(find.text('1 transaction'), findsOneWidget);
    expect(find.text('2026-01-01'), findsOneWidget);
    expect(find.textContaining('Net'), findsNothing);
  });
}

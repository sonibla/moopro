import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/selection_stats.dart';
import 'package:moopro/domain/transaction_list_grouping.dart';
import 'package:moopro/widgets/amount_text.dart';

const _eur = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
);
const _usd = Asset(id: 'usd', kind: AssetKind.fiat, symbol: 'USD', name: 'US');
const _btc = Asset(
  id: 'btc',
  kind: AssetKind.crypto,
  symbol: 'BTC',
  name: 'Bitcoin',
);

TransactionRowItem _row(
  TransactionKind kind,
  String q,
  Asset asset, {
  CalendarDate? date,
  Asset? assetIn,
  String? qIn,
}) {
  final d = date ?? CalendarDate(2026, 1, 1);
  return TransactionRowItem(
    row: ldb.Transaction(
      id: 'x',
      postedAt: d.toDateTime(),
      effectiveDate: d,
      kind: kind.name,
      legOutContainerId: 'a',
      legOutAssetId: asset.id,
      legOutQuantity: q,
      legInContainerId: 'b',
      legInAssetId: asset.id,
      legInQuantity: q,
      tags: '[]',
      manualOrderRank: 0,
      deleted: false,
    ),
    id: 'x',
    effectiveDate: d,
    postedAt: d.toDateTime(),
    title: 't',
    displayQuantity: Decimal.parse(q),
    displayAsset: asset,
    sign: AmountSign.neutral,
    kind: kind,
    tradeAssetIn: assetIn,
    tradeQuantityIn: qIn == null ? null : Decimal.parse(qIn),
  );
}

void main() {
  test('empty selection', () {
    final s = computeSelectionStats(const []);
    expect(s.count, 0);
    expect(s.byKind, isEmpty);
    expect(s.net, isEmpty);
    expect(s.firstDate, isNull);
  });

  test('counts and per-asset sums per kind, never mixing assets', () {
    final s = computeSelectionStats([
      _row(TransactionKind.income, '100', _eur),
      _row(TransactionKind.income, '50.5', _eur),
      _row(TransactionKind.income, '10', _usd),
      _row(TransactionKind.expense, '30', _eur),
      _row(TransactionKind.holderTransfer, '5', _eur),
    ]);
    expect(s.count, 5);
    expect(s.byKind.map((k) => (k.kind, k.count)), [
      (TransactionKind.income, 3),
      (TransactionKind.expense, 1),
      (TransactionKind.holderTransfer, 1),
    ]);
    final income = s.byKind.first;
    expect(income.totals.map((t) => (t.asset.id, t.total.toString())), [
      ('eur', '150.5'),
      ('usd', '10'),
    ]);
  });

  test('net is income minus expense per asset, ignoring transfers/trades', () {
    final s = computeSelectionStats([
      _row(TransactionKind.income, '100', _eur),
      _row(TransactionKind.expense, '130', _eur),
      _row(TransactionKind.expense, '2', _usd),
      _row(TransactionKind.budgetTransfer, '999', _eur),
      _row(TransactionKind.trade, '999', _eur, assetIn: _btc, qIn: '1'),
    ]);
    expect(s.net.map((t) => (t.asset.id, t.total.toString())), [
      ('eur', '-30'),
      ('usd', '-2'),
    ]);
  });

  test('trades also total the received side', () {
    final s = computeSelectionStats([
      _row(TransactionKind.trade, '500', _eur, assetIn: _btc, qIn: '0.01'),
      _row(TransactionKind.trade, '100', _eur, assetIn: _btc, qIn: '0.002'),
    ]);
    final trade = s.byKind.single;
    expect(trade.totals.single.total.toString(), '600');
    expect(trade.totalsIn.single.asset.id, 'btc');
    expect(trade.totalsIn.single.total.toString(), '0.012');
  });

  test('date range spans earliest to latest effective date', () {
    final s = computeSelectionStats([
      _row(TransactionKind.income, '1', _eur, date: CalendarDate(2026, 3, 5)),
      _row(TransactionKind.income, '1', _eur, date: CalendarDate(2026, 1, 9)),
      _row(TransactionKind.income, '1', _eur, date: CalendarDate(2026, 2, 1)),
    ]);
    expect(s.firstDate, CalendarDate(2026, 1, 9));
    expect(s.lastDate, CalendarDate(2026, 3, 5));
  });
}

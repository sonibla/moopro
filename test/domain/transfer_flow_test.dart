import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_filter.dart';
import 'package:moopro/domain/transaction_list_grouping.dart';
import 'package:moopro/domain/transfer_flow.dart';

const _eur = ldb.Asset(
  id: 'eur',
  kind: 'fiat',
  symbol: 'EUR',
  name: 'Euro',
  deleted: false,
);

final _day = CalendarDate(2026, 1, 18);

ldb.Transaction _tx(
  String id,
  String from,
  String to,
  String quantity, {
  TransactionKind kind = TransactionKind.budgetTransfer,
}) => ldb.Transaction(
  id: id,
  postedAt: _day.toDateTime(),
  effectiveDate: _day,
  kind: kind.name,
  legOutContainerId: from,
  legOutAssetId: 'eur',
  legOutQuantity: quantity,
  legInContainerId: to,
  legInAssetId: 'eur',
  legInQuantity: quantity,
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

TransactionGroupItem _group(List<ldb.Transaction> rows) {
  final items = buildTransactionListItems(
    TransactionListGroupInput(
      rows: rows,
      filter: TransactionFilter.empty,
      containerNames: const {},
      assetsById: const {'eur': _eur},
      now: DateTime.utc(2026, 1, 20),
    ),
  );
  return items.whereType<TransactionGroupItem>().first;
}

TransferFlow _flow(List<ldb.Transaction> rows) =>
    TransferFlow.fromGroup(_group(rows), (id) => id.toUpperCase());

Map<String, int> _layers(TransferFlow f) => {
  for (final n in f.nodes) n.id: n.layer,
};

void main() {
  group('TransferFlow.fromGroup', () {
    test('a flat group is a source column feeding a destination column', () {
      final f = _flow([
        _tx('a', 'inc', 'rent', '30'),
        _tx('b', 'inc', 'fun', '20'),
      ]);
      expect(_layers(f), {'inc': 0, 'rent': 1, 'fun': 1});
      expect(f.links, hasLength(2));
      expect(f.links.every((l) => !l.isBack), isTrue);
      final inc = f.nodes.firstWhere((n) => n.id == 'inc');
      expect(inc.value, Decimal.parse('50'));
      expect(inc.name, 'INC');
      expect(f.asset.id, 'eur');
    });

    test('nested groups add columns: Income -> budgets -> children', () {
      final f = _flow([
        _tx('a', 'inc', 'housing', '100'),
        _tx('b', 'inc', 'invest', '50'),
        _tx('c', 'housing', 'rent', '70'),
        _tx('d', 'housing', 'utils', '30'),
      ]);
      expect(_layers(f), {
        'inc': 0,
        'housing': 1,
        'invest': 1,
        'rent': 2,
        'utils': 2,
      });
      expect(
        f.nodes.firstWhere((n) => n.id == 'housing').value,
        Decimal.parse('100'),
      );
    });

    test('a container fed by two parents is one node, in the later column', () {
      final f = _flow([
        _tx('a', 'inc', 'x', '10'),
        _tx('b', 'inc', 'y', '10'),
        _tx('c', 'x', 'z', '4'),
        _tx('d', 'y', 'z', '6'),
      ]);
      expect(f.nodes.where((n) => n.id == 'z'), hasLength(1));
      expect(_layers(f)['z'], 2);
      expect(f.nodes.firstWhere((n) => n.id == 'z').value, Decimal.parse('10'));
      expect(f.links.where((l) => l.isBack), isEmpty);
    });

    test('a transfer closing a cycle is kept and flagged as a back link', () {
      final f = _flow([
        _tx('a', 'inc', 'x', '10'),
        _tx('b', 'inc', 'y', '5'),
        _tx('c', 'x', 'inc', '3'),
      ]);
      final back = f.links.where((l) => l.isBack).toList();
      expect(back, hasLength(1));
      expect((back.single.from, back.single.to), ('x', 'inc'));
      expect(back.single.value, Decimal.parse('3'));
      expect(_layers(f)['inc'], 0);
      expect(_layers(f)['x'], 1);
      expect(f.links, hasLength(3));
    });

    test('repeated pairs are summed into one link', () {
      final f = _flow([
        _tx('a', 'inc', 'x', '10'),
        _tx('b', 'inc', 'x', '5.5'),
        _tx('c', 'inc', 'y', '1'),
      ]);
      final link = f.links.firstWhere((l) => l.to == 'x');
      expect(link.value, Decimal.parse('15.5'));
      expect(f.links, hasLength(2));
    });

    test('works for holder transfers too', () {
      final f = _flow([
        _tx('a', 'bank', 'broker', '10', kind: TransactionKind.holderTransfer),
        _tx('b', 'bank', 'cash', '5', kind: TransactionKind.holderTransfer),
      ]);
      expect(_layers(f), {'bank': 0, 'broker': 1, 'cash': 1});
    });
  });
}

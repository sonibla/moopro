import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/holder_budget_consistency.dart';
import 'package:moopro/domain/calendar_date.dart';

Container _container(String id, String containerType, {String? parentId}) =>
    Container(
      id: id,
      name: id,
      containerType: containerType,
      parentId: parentId,
      deleted: false,
    );

void main() {
  late DomainCacheDatabase db;
  late BalanceEngine balanceEngine;

  setUp(() {
    db = DomainCacheDatabase(NativeDatabase.memory());
    balanceEngine = BalanceEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> move(
    String id,
    String outContainerId,
    String outAssetId,
    String outQuantity,
    String inContainerId,
    String inAssetId,
    String inQuantity, {
    CalendarDate? date,
  }) async {
    final effectiveDate = date ?? CalendarDate(2026, 1, 1);
    await db
        .into(db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion(
            id: Value(id),
            postedAt: Value(effectiveDate.toDateTime()),
            effectiveDate: Value(effectiveDate),
            kind: const Value('trade'),
            legOutContainerId: Value(outContainerId),
            legOutAssetId: Value(outAssetId),
            legOutQuantity: Value(outQuantity),
            legInContainerId: Value(inContainerId),
            legInAssetId: Value(inAssetId),
            legInQuantity: Value(inQuantity),
            deleted: const Value(false),
          ),
        );
    await balanceEngine.onTransactionChanged(
      oldLegs: null,
      newLegs: [
        MapEntry(outContainerId, outAssetId),
        MapEntry(inContainerId, inAssetId),
      ],
      newDate: effectiveDate,
    );
  }

  test(
    'income into a holder and its budget in lockstep stays consistent',
    () async {
      await move('inc', 'external', 'eur', '1000', 'bank', 'eur', '1000');
      await move(
        'inc-budget',
        'externalBudget',
        'eur',
        '1000',
        'income',
        'eur',
        '1000',
      );

      final containers = [
        _container('bank', 'holder'),
        _container('income', 'budget'),
      ];
      final consistency = await computeHolderBudgetConsistency(
        balanceEngine: balanceEngine,
        containers: containers,
      );

      expect(consistency.holderBalances, {'eur': Decimal.parse('1000')});
      expect(consistency.budgetBalances, {'eur': Decimal.parse('1000')});
      expect(consistency.isConsistent, isTrue);
      expect(consistency.mismatchesByAsset, isEmpty);
    },
  );

  test('mixed-asset holdings still match when nothing has traded', () async {
    await move('inc-eur', 'external', 'eur', '1', 'bank', 'eur', '1');
    await move(
      'inc-eur-budget',
      'externalBudget',
      'eur',
      '1',
      'savings',
      'eur',
      '1',
    );
    await move('inc-btc', 'external', 'btc', '1', 'bank', 'btc', '1');
    await move(
      'inc-btc-budget',
      'externalBudget',
      'btc',
      '1',
      'savings',
      'btc',
      '1',
    );

    final containers = [
      _container('bank', 'holder'),
      _container('savings', 'budget'),
    ];
    final consistency = await computeHolderBudgetConsistency(
      balanceEngine: balanceEngine,
      containers: containers,
    );

    expect(consistency.holderBalances, {
      'eur': Decimal.parse('1'),
      'btc': Decimal.parse('1'),
    });
    expect(consistency.budgetBalances, {
      'eur': Decimal.parse('1'),
      'btc': Decimal.parse('1'),
    });
    expect(consistency.isConsistent, isTrue);
  });

  test(
    'a trade that converts an asset within a holder, with no matching '
    'budget-side move, is reported as inconsistent immediately — no price '
    'data involved at all. This is the pre-`recordTrade`-required-budget '
    'shape (now only reachable via a manually-constructed record or '
    'data written before that requirement existed — see data-model.md)',
    () async {
      await move('inc', 'external', 'eur', '1000', 'bank', 'eur', '1000');
      await move(
        'inc-budget',
        'externalBudget',
        'eur',
        '1000',
        'savings',
        'eur',
        '1000',
      );
      await move('trade', 'bank', 'eur', '500', 'bank', 'btc', '5');

      final containers = [
        _container('bank', 'holder'),
        _container('savings', 'budget'),
      ];
      final consistency = await computeHolderBudgetConsistency(
        balanceEngine: balanceEngine,
        containers: containers,
      );

      expect(consistency.holderBalances, {
        'eur': Decimal.parse('500'),
        'btc': Decimal.parse('5'),
      });
      expect(consistency.budgetBalances, {'eur': Decimal.parse('1000')});
      expect(consistency.isConsistent, isFalse);
      expect(consistency.mismatchesByAsset, {
        'eur': Decimal.parse('-500'),
        'btc': Decimal.parse('5'),
      });
    },
  );

  test('a trade that also moves a matching budget leg (the shape '
      '`DomainRepository.recordTrade` now always produces) stays '
      'consistent — closing the gap the previous test demonstrates', () async {
    await move('inc', 'external', 'eur', '1000', 'bank', 'eur', '1000');
    await move(
      'inc-budget',
      'externalBudget',
      'eur',
      '1000',
      'savings',
      'eur',
      '1000',
    );
    await move('trade', 'bank', 'eur', '500', 'bank', 'btc', '5');
    await move('trade-budget', 'savings', 'eur', '500', 'savings', 'btc', '5');

    final containers = [
      _container('bank', 'holder'),
      _container('savings', 'budget'),
    ];
    final consistency = await computeHolderBudgetConsistency(
      balanceEngine: balanceEngine,
      containers: containers,
    );

    expect(consistency.holderBalances, {
      'eur': Decimal.parse('500'),
      'btc': Decimal.parse('5'),
    });
    expect(consistency.budgetBalances, {
      'eur': Decimal.parse('500'),
      'btc': Decimal.parse('5'),
    });
    expect(consistency.isConsistent, isTrue);
    expect(consistency.mismatchesByAsset, isEmpty);
  });
}

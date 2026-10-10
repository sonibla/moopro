import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/models.dart'
    show externalBudgetContainerId, externalHolderContainerId;

void main() {
  late DomainCacheDatabase db;
  late BalanceEngine engine;

  setUp(() {
    db = DomainCacheDatabase(NativeDatabase.memory());
    engine = BalanceEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertTx({
    required String id,
    required CalendarDate date,
    required String outContainer,
    required String inContainer,
    required String quantity,
    String asset = 'eur',
    String kind = 'holderTransfer',
    String? budgetOutContainer,
    String? budgetInContainer,
    DateTime? postedAt,
    int manualOrderRank = 0,
    bool deleted = false,
  }) async {
    await db
        .into(db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion(
            id: Value(id),
            postedAt: Value(postedAt ?? date.toDateTime()),
            effectiveDate: Value(date),
            kind: Value(kind),
            legOutContainerId: Value(outContainer),
            legOutAssetId: Value(asset),
            legOutQuantity: Value(quantity),
            legInContainerId: Value(inContainer),
            legInAssetId: Value(asset),
            legInQuantity: Value(quantity),
            budgetLegOutContainerId: Value(budgetOutContainer),
            budgetLegOutAssetId: Value(
              budgetOutContainer == null ? null : asset,
            ),
            budgetLegOutQuantity: Value(
              budgetOutContainer == null ? null : quantity,
            ),
            budgetLegInContainerId: Value(budgetInContainer),
            budgetLegInAssetId: Value(budgetInContainer == null ? null : asset),
            budgetLegInQuantity: Value(
              budgetInContainer == null ? null : quantity,
            ),
            manualOrderRank: Value(manualOrderRank),
            deleted: Value(deleted),
          ),
        );
  }

  List<MapEntry<String, String>> legs({
    required String out,
    required String inn,
    String? budgetOut,
    String? budgetIn,
    String asset = 'eur',
  }) => [
    MapEntry(out, asset),
    MapEntry(inn, asset),
    if (budgetOut != null) MapEntry(budgetOut, asset),
    if (budgetIn != null) MapEntry(budgetIn, asset),
  ];

  test(
    'a fresh (container, asset) pair with no activity has zero balance',
    () async {
      expect(await engine.currentBalance('bank1', 'eur'), equals(Decimal.zero));
    },
  );

  test('a single inbound transaction increases the balance', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 15),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '100.00',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      newDate: CalendarDate(2026, 1, 15),
    );

    expect(
      await engine.currentBalance('bank1', 'eur'),
      equals(Decimal.parse('100.00')),
    );
    expect(
      await engine.currentBalance('external', 'eur'),
      equals(Decimal.parse('-100.00')),
    );
  });

  test('checkpoints accumulate across multiple months', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 15),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '100',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      newDate: CalendarDate(2026, 1, 15),
    );

    await insertTx(
      id: 'tx2',
      date: CalendarDate(2026, 3, 1),
      outContainer: 'bank1',
      inContainer: 'budgetA',
      quantity: '30',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('bank1', 'eur'), MapEntry('budgetA', 'eur')],
      newDate: CalendarDate(2026, 3, 1),
    );

    expect(
      await engine.currentBalance('bank1', 'eur'),
      equals(Decimal.parse('70')),
    );
    expect(
      await engine.currentBalance('budgetA', 'eur'),
      equals(Decimal.parse('30')),
    );

    final bankCheckpoints = await (db.select(
      db.balanceCheckpoints,
    )..where((t) => t.containerId.equals('bank1'))).get();
    expect(bankCheckpoints.map((c) => c.checkpointDate.toUtc()).toSet(), {
      DateTime.utc(2026, 1),
      DateTime.utc(2026, 3),
    });
  });

  test(
    'editing a transaction date only rebuilds affected checkpoints',
    () async {
      await insertTx(
        id: 'tx1',
        date: CalendarDate(2026, 1, 10),
        outContainer: 'external',
        inContainer: 'bank1',
        quantity: '100',
      );
      await engine.onTransactionChanged(
        oldLegs: null,
        newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
        newDate: CalendarDate(2026, 1, 10),
      );
      expect(
        await engine.currentBalance('bank1', 'eur'),
        equals(Decimal.parse('100')),
      );

      await insertTx(
        id: 'tx1',
        date: CalendarDate(2026, 3, 10),
        outContainer: 'external',
        inContainer: 'bank1',
        quantity: '100',
      );
      await engine.onTransactionChanged(
        oldLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
        oldDate: CalendarDate(2026, 1, 10),
        newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
        newDate: CalendarDate(2026, 3, 10),
      );

      expect(
        await engine.currentBalance('bank1', 'eur'),
        equals(Decimal.parse('100')),
      );
      final checkpoints = await (db.select(
        db.balanceCheckpoints,
      )..where((t) => t.containerId.equals('bank1'))).get();
      expect(checkpoints, hasLength(1));
      expect(
        checkpoints.single.checkpointDate.toUtc(),
        equals(DateTime.utc(2026, 3)),
      );
    },
  );

  test('deleting a transaction removes its contribution', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 10),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '100',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      newDate: CalendarDate(2026, 1, 10),
    );

    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 10),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '100',
      deleted: true,
    );
    await engine.onTransactionChanged(
      oldLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      oldDate: CalendarDate(2026, 1, 10),
      newLegs: null,
    );

    expect(await engine.currentBalance('bank1', 'eur'), equals(Decimal.zero));
  });

  test('rebuildAll reconstructs checkpoints for every active pair', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 10),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '50',
    );
    await insertTx(
      id: 'tx2',
      date: CalendarDate(2026, 2, 5),
      outContainer: 'bank1',
      inContainer: 'budgetA',
      quantity: '20',
    );

    await engine.rebuildAll();

    expect(
      await engine.currentBalance('bank1', 'eur'),
      equals(Decimal.parse('30')),
    );
    expect(
      await engine.currentBalance('budgetA', 'eur'),
      equals(Decimal.parse('20')),
    );
    expect(
      await engine.currentBalance('external', 'eur'),
      equals(Decimal.parse('-50')),
    );
  });

  test('rebuildAll commits once per distinct (container, asset) pair, not '
      'once per transaction (perf regression: an unwrapped write loop would '
      'fire the Transactions watch stream once per row)', () async {
    for (var i = 0; i < 4; i++) {
      await insertTx(
        id: 'ext$i',
        date: CalendarDate(2026, 1, 1 + i),
        outContainer: 'external',
        inContainer: 'bank1',
        quantity: '10',
      );
    }
    for (var i = 0; i < 4; i++) {
      await insertTx(
        id: 'a$i',
        date: CalendarDate(2026, 1, 1 + i),
        outContainer: 'bank1',
        inContainer: 'budgetA',
        quantity: '5',
      );
    }
    for (var i = 0; i < 4; i++) {
      await insertTx(
        id: 'b$i',
        date: CalendarDate(2026, 1, 1 + i),
        outContainer: 'bank1',
        inContainer: 'budgetB',
        quantity: '5',
      );
    }

    final emissions = <int>[];
    final sub = db
        .select(db.transactions)
        .watch()
        .listen((rows) => emissions.add(rows.length));
    await pumpEventQueue();
    final countBefore = emissions.length;

    await engine.rebuildAll();
    await pumpEventQueue();
    await sub.cancel();

    expect(emissions.length - countBefore, equals(4));
  });

  test(
    'an income row moves the holder AND budget legs, keeping their totals equal',
    () async {
      await insertTx(
        id: 'tx1',
        date: CalendarDate(2026, 1, 10),
        kind: 'income',
        outContainer: 'externalHolder',
        inContainer: 'bank1',
        budgetOutContainer: 'externalBudget',
        budgetInContainer: 'budgetA',
        quantity: '100',
      );
      await engine.onTransactionChanged(
        oldLegs: null,
        newLegs: legs(
          out: 'externalHolder',
          inn: 'bank1',
          budgetOut: 'externalBudget',
          budgetIn: 'budgetA',
        ),
        newDate: CalendarDate(2026, 1, 10),
      );

      expect(
        await engine.currentBalance('bank1', 'eur'),
        equals(Decimal.parse('100')),
      );
      expect(
        await engine.currentBalance('budgetA', 'eur'),
        equals(Decimal.parse('100')),
      );
    },
  );

  test('rebuildAll picks up budget legs from an income/expense row', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 10),
      kind: 'income',
      outContainer: 'externalHolder',
      inContainer: 'bank1',
      budgetOutContainer: 'externalBudget',
      budgetInContainer: 'budgetA',
      quantity: '100',
    );

    await engine.rebuildAll();

    expect(
      await engine.currentBalance('bank1', 'eur'),
      equals(Decimal.parse('100')),
    );
    expect(
      await engine.currentBalance('budgetA', 'eur'),
      equals(Decimal.parse('100')),
    );
    expect(
      await engine.currentBalance('externalHolder', 'eur'),
      equals(Decimal.parse('-100')),
    );
    expect(
      await engine.currentBalance('externalBudget', 'eur'),
      equals(Decimal.parse('-100')),
    );
  });

  test('assetBalances returns every asset a container currently holds a '
      'nonzero balance of, not just one', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 5),
      outContainer: 'external',
      inContainer: 'broker1',
      quantity: '1000',
      asset: 'eur',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('broker1', 'eur')],
      newDate: CalendarDate(2026, 1, 5),
    );
    await insertTx(
      id: 'tx2',
      date: CalendarDate(2026, 1, 10),
      outContainer: 'external',
      inContainer: 'broker1',
      quantity: '3.2',
      asset: 'aapl',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [
        MapEntry('external', 'aapl'),
        MapEntry('broker1', 'aapl'),
      ],
      newDate: CalendarDate(2026, 1, 10),
    );

    final balances = await engine.assetBalances('broker1');
    expect(balances, {
      'eur': Decimal.parse('1000'),
      'aapl': Decimal.parse('3.2'),
    });
  });

  test('assetBalances omits an asset whose balance has been fully spent '
      'down/traded away to zero', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 5),
      outContainer: 'external',
      inContainer: 'broker1',
      quantity: '5',
      asset: 'aapl',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [
        MapEntry('external', 'aapl'),
        MapEntry('broker1', 'aapl'),
      ],
      newDate: CalendarDate(2026, 1, 5),
    );
    await insertTx(
      id: 'tx2',
      date: CalendarDate(2026, 1, 10),
      outContainer: 'broker1',
      inContainer: 'external',
      quantity: '5',
      asset: 'aapl',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [
        MapEntry('broker1', 'aapl'),
        MapEntry('external', 'aapl'),
      ],
      newDate: CalendarDate(2026, 1, 10),
    );

    expect(await engine.assetBalances('broker1'), isEmpty);
  });

  test(
    'assetBalances returns an empty map for a container with no activity',
    () async {
      expect(await engine.assetBalances('nobody'), isEmpty);
    },
  );

  test('assetBalances only ever returns the latest checkpoint per asset, '
      'not every historical one', () async {
    await insertTx(
      id: 'tx1',
      date: CalendarDate(2026, 1, 5),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '100',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      newDate: CalendarDate(2026, 1, 5),
    );
    await insertTx(
      id: 'tx2',
      date: CalendarDate(2026, 3, 1),
      outContainer: 'external',
      inContainer: 'bank1',
      quantity: '50',
    );
    await engine.onTransactionChanged(
      oldLegs: null,
      newLegs: const [MapEntry('external', 'eur'), MapEntry('bank1', 'eur')],
      newDate: CalendarDate(2026, 3, 1),
    );

    final balances = await engine.assetBalances('bank1');
    expect(balances, {'eur': Decimal.parse('150')});
  });

  group('same-day ordering (sameDaySafeOrder)', () {
    test('the exact reported repro: a same-day holder transfer that funds a '
        'trade replays before it, even though the trade was recorded '
        '(postedAt) first', () async {
      final day1 = CalendarDate(2026, 1, 1);
      final day3 = CalendarDate(2026, 1, 3);
      await insertTx(
        id: 'income',
        date: day1,
        outContainer: 'external',
        inContainer: 'bank1',
        quantity: '1000',
      );
      await db
          .into(db.transactions)
          .insertOnConflictUpdate(
            TransactionsCompanion(
              id: const Value('trade'),
              postedAt: Value(day3.toDateTime().add(const Duration(hours: 8))),
              effectiveDate: Value(day3),
              kind: const Value('trade'),
              legOutContainerId: const Value('bank2'),
              legOutAssetId: const Value('eur'),
              legOutQuantity: const Value('1000'),
              legInContainerId: const Value('bank2'),
              legInAssetId: const Value('shares'),
              legInQuantity: const Value('10'),
              deleted: const Value(false),
            ),
          );
      await insertTx(
        id: 'transfer',
        date: day3,
        outContainer: 'bank1',
        inContainer: 'bank2',
        quantity: '1000',
        postedAt: day3.toDateTime().add(const Duration(hours: 9)),
      );

      await engine.rebuildAll();

      final trade = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('trade'))).getSingle();
      expect(Decimal.parse(trade.legOutBalanceAfter!), equals(Decimal.zero));
      final transfer = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('transfer'))).getSingle();
      expect(
        Decimal.parse(transfer.legInBalanceAfter!),
        equals(Decimal.parse('1000')),
      );
    });

    test(
      'a same-day income and expense never form a spurious dependency '
      'through the shared external sentinel, regardless of postedAt',
      () async {
        final day = CalendarDate(2026, 1, 10);
        await insertTx(
          id: 'expense',
          date: day,
          kind: 'expense',
          outContainer: 'bank1',
          inContainer: externalHolderContainerId,
          budgetOutContainer: 'budgetA',
          budgetInContainer: externalBudgetContainerId,
          quantity: '50',
          postedAt: day.toDateTime().add(const Duration(hours: 1)),
        );
        await insertTx(
          id: 'income',
          date: day,
          kind: 'income',
          outContainer: externalHolderContainerId,
          inContainer: 'bank1',
          budgetOutContainer: externalBudgetContainerId,
          budgetInContainer: 'budgetA',
          quantity: '100',
          postedAt: day.toDateTime().add(const Duration(hours: 23)),
        );

        await engine.rebuildAll();

        final expenseRow = await (db.select(
          db.transactions,
        )..where((t) => t.id.equals('expense'))).getSingle();
        expect(
          Decimal.parse(expenseRow.legOutBalanceAfter!),
          equals(Decimal.parse('50')),
        );
      },
    );

    test('manualOrderRank governs replay order (not just display order) for '
        'two unrelated same-day transactions, taking precedence over '
        'postedAt — replay must match display exactly, or the cached '
        'balanceAfter would disagree with what the list shows', () async {
      final day1 = CalendarDate(2026, 1, 1);
      final day2 = CalendarDate(2026, 1, 2);
      await insertTx(
        id: 'funding',
        date: day1,
        outContainer: externalHolderContainerId,
        inContainer: 'bank1',
        quantity: '1000',
      );
      await insertTx(
        id: 'rankFirst',
        date: day2,
        outContainer: 'bank1',
        inContainer: externalHolderContainerId,
        quantity: '300',
        postedAt: day2.toDateTime().add(const Duration(hours: 20)),
        manualOrderRank: 1,
      );
      await insertTx(
        id: 'rankSecond',
        date: day2,
        outContainer: 'bank1',
        inContainer: externalHolderContainerId,
        quantity: '300',
        postedAt: day2.toDateTime().add(const Duration(hours: 1)),
        manualOrderRank: 2,
      );

      await engine.rebuildAll();

      final rankFirstRow = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('rankFirst'))).getSingle();
      final rankSecondRow = await (db.select(
        db.transactions,
      )..where((t) => t.id.equals('rankSecond'))).getSingle();
      expect(
        Decimal.parse(rankFirstRow.legOutBalanceAfter!),
        equals(Decimal.parse('700')),
      );
      expect(
        Decimal.parse(rankSecondRow.legOutBalanceAfter!),
        equals(Decimal.parse('400')),
      );
    });
  });
}

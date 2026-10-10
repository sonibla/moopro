import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/models.dart' show AssetKind;
import 'package:moopro/domain/multi_asset_rollup.dart';
import 'package:moopro/domain/price_engine.dart';
import 'package:moopro/domain/calendar_date.dart';

Container _container(String id, {String? parentId}) => Container(
  id: id,
  name: id,
  containerType: 'budget',
  parentId: parentId,
  deleted: false,
);

void main() {
  late DomainCacheDatabase db;
  late BalanceEngine balanceEngine;
  late PriceEngine priceEngine;

  setUp(() {
    db = DomainCacheDatabase(NativeDatabase.memory());
    balanceEngine = BalanceEngine(db);
    priceEngine = PriceEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> hold(
    String containerId,
    String assetId,
    String quantity, {
    CalendarDate? date,
  }) async {
    final effectiveDate = date ?? CalendarDate(2026, 1, 1);
    await db
        .into(db.transactions)
        .insertOnConflictUpdate(
          TransactionsCompanion(
            id: Value('${containerId}_$assetId'),
            postedAt: Value(effectiveDate.toDateTime()),
            effectiveDate: Value(effectiveDate),
            kind: const Value('holderTransfer'),
            legOutContainerId: const Value('external'),
            legOutAssetId: Value(assetId),
            legOutQuantity: Value(quantity),
            legInContainerId: Value(containerId),
            legInAssetId: Value(assetId),
            legInQuantity: Value(quantity),
            deleted: const Value(false),
          ),
        );
    await balanceEngine.onTransactionChanged(
      oldLegs: null,
      newLegs: [MapEntry('external', assetId), MapEntry(containerId, assetId)],
      newDate: effectiveDate,
    );
  }

  Future<void> price(
    String assetId,
    String currencyAssetId,
    String value, {
    DateTime? date,
  }) async {
    await db
        .into(db.priceSnapshots)
        .insert(
          PriceSnapshotsCompanion.insert(
            id: '${assetId}_in_${currencyAssetId}_${date?.toIso8601String() ?? 'default'}',
            assetId: assetId,
            date: date ?? DateTime.utc(2026, 1, 1),
            price: value,
            currencyAssetId: currencyAssetId,
            source: 'manual',
          ),
        );
  }

  const assetsById = {
    'aapl': Asset(
      id: 'aapl',
      kind: 'stock',
      symbol: 'AAPL',
      name: 'Apple',
      deleted: false,
    ),
    'btc': Asset(
      id: 'btc',
      kind: 'crypto',
      symbol: 'BTC',
      name: 'Bitcoin',
      deleted: false,
    ),
    'goog': Asset(
      id: 'goog',
      kind: 'stock',
      symbol: 'GOOG',
      name: 'Alphabet',
      deleted: false,
    ),
    'loan': Asset(
      id: 'loan',
      kind: 'other',
      symbol: 'LOAN',
      name: 'Loan',
      deleted: false,
    ),
    'eur': Asset(
      id: 'eur',
      kind: 'fiat',
      symbol: 'EUR',
      name: 'Euro',
      deleted: false,
    ),
  };

  group('computeMultiAssetRollup', () {
    test('converts a single held asset into the display asset', () async {
      await hold('broker', 'aapl', '10');
      await price('aapl', 'eur', '170');

      final rollup = await computeMultiAssetRollup(
        balanceEngine: balanceEngine,
        priceEngine: priceEngine,
        containers: [_container('broker')],
        displayAssetId: 'eur',
      );

      expect(rollup.ownPositive['broker'], equals(Decimal.parse('1700')));
      expect(rollup.ownDebt['broker'], isNull);
      expect(rollup.containersWithUnconvertible, isEmpty);
    });

    test('a container holding both a positive asset and a debt-asset keeps '
        'them in separate maps — never netted into one number', () async {
      await hold('mixed', 'aapl', '10');
      await hold('mixed', 'loan', '-500');
      await price('aapl', 'eur', '170');
      await price('loan', 'eur', '1');

      final rollup = await computeMultiAssetRollup(
        balanceEngine: balanceEngine,
        priceEngine: priceEngine,
        containers: [_container('mixed')],
        displayAssetId: 'eur',
      );

      expect(rollup.ownPositive['mixed'], equals(Decimal.parse('1700')));
      expect(rollup.ownDebt['mixed'], equals(Decimal.parse('-500')));
    });

    test('an asset with no known price is surfaced (raw holding kept, '
        'convertedValue null) rather than dropped or guessed at, and marks '
        'the container plus every ancestor as unconvertible', () async {
      await hold('crypto', 'btc', '0.5');

      final containers = [
        _container('investments'),
        _container('crypto', parentId: 'investments'),
      ];
      final rollup = await computeMultiAssetRollup(
        balanceEngine: balanceEngine,
        priceEngine: priceEngine,
        containers: containers,
        displayAssetId: 'eur',
      );

      expect(rollup.ownPositive['crypto'], isNull);
      expect(rollup.ownDebt['crypto'], isNull);
      final holdings = rollup.ownHoldings['crypto']!;
      expect(holdings, hasLength(1));
      expect(holdings.single.assetId, equals('btc'));
      expect(holdings.single.quantity, equals(Decimal.parse('0.5')));
      expect(holdings.single.convertedValue, isNull);
      expect(rollup.containersWithUnconvertible, {'crypto', 'investments'});
    });

    test(
      'a container with no holdings at all has no entry in ownHoldings',
      () async {
        final rollup = await computeMultiAssetRollup(
          balanceEngine: balanceEngine,
          priceEngine: priceEngine,
          containers: [_container('empty')],
          displayAssetId: 'eur',
        );
        expect(rollup.ownHoldings.containsKey('empty'), isFalse);
      },
    );

    test('converting an asset into itself uses the identity rate (no price '
        'snapshot needed)', () async {
      await hold('bank', 'eur', '250');

      final rollup = await computeMultiAssetRollup(
        balanceEngine: balanceEngine,
        priceEngine: priceEngine,
        containers: [_container('bank')],
        displayAssetId: 'eur',
      );

      expect(rollup.ownPositive['bank'], equals(Decimal.parse('250')));
      expect(rollup.containersWithUnconvertible, isEmpty);
    });
  });

  group('computeAssetKindRollup', () {
    test('sums the *converted* value of every asset of the requested kind, '
        'ignoring assets of other kinds', () async {
      await hold('broker', 'aapl', '10');
      await hold('broker', 'goog', '2');
      await hold('broker', 'eur', '500');
      await price('aapl', 'eur', '170');
      await price('goog', 'eur', '140');

      final rollup = await computeAssetKindRollup(
        balanceEngine: balanceEngine,
        priceEngine: priceEngine,
        containers: [_container('broker')],
        displayAssetId: 'eur',
        kind: AssetKind.stock,
        assetsById: assetsById,
      );

      expect(rollup.ownPositive['broker'], equals(Decimal.parse('1980')));
    });
  });

  group('computeSingleAssetBalances', () {
    test('returns raw, unconverted balances only for containers holding '
        'that exact asset', () async {
      await hold('crypto', 'btc', '0.5');
      await hold('broker', 'aapl', '10');

      final balances = await computeSingleAssetBalances(
        balanceEngine: balanceEngine,
        containers: [_container('crypto'), _container('broker')],
        assetId: 'btc',
      );

      expect(balances, {'crypto': Decimal.parse('0.5')});
    });
  });

  group('containersInFilteredSubtree', () {
    test('includes every ancestor of a directly-holding container, and '
        'excludes unrelated top-level containers entirely', () async {
      final containers = [
        _container('investments'),
        _container('crypto', parentId: 'investments'),
        _container('savings'),
      ];
      final result = containersInFilteredSubtree({'crypto'}, containers);
      expect(result, {'crypto', 'investments'});
      expect(result.contains('savings'), isFalse);
    });
  });

  group('mergeHoldingsByAsset', () {
    test('sums quantity and convertedValue across containers for the same '
        'asset', () {
      final merged = mergeHoldingsByAsset([
        [
          AssetHolding(
            assetId: 'aapl',
            quantity: Decimal.parse('3'),
            convertedValue: Decimal.parse('510'),
          ),
        ],
        [
          AssetHolding(
            assetId: 'aapl',
            quantity: Decimal.parse('2'),
            convertedValue: Decimal.parse('340'),
          ),
        ],
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.quantity, equals(Decimal.parse('5')));
      expect(merged.single.convertedValue, equals(Decimal.parse('850')));
    });

    test('a mixed null/non-null convertedValue for the same asset id '
        'degrades to null rather than silently reporting a partial total '
        'as if it were complete', () {
      final merged = mergeHoldingsByAsset([
        [
          AssetHolding(
            assetId: 'btc',
            quantity: Decimal.fromInt(1),
            convertedValue: null,
          ),
        ],
        [
          AssetHolding(
            assetId: 'btc',
            quantity: Decimal.fromInt(1),
            convertedValue: Decimal.parse('40000'),
          ),
        ],
      ]);
      expect(merged.single.convertedValue, isNull);
      expect(merged.single.quantity, equals(Decimal.fromInt(2)));
    });

    test('different assets stay as separate rows, sorted by assetId', () {
      final merged = mergeHoldingsByAsset([
        [
          AssetHolding(
            assetId: 'eur',
            quantity: Decimal.fromInt(100),
            convertedValue: null,
          ),
          AssetHolding(
            assetId: 'aapl',
            quantity: Decimal.fromInt(1),
            convertedValue: null,
          ),
        ],
      ]);
      expect(merged.map((h) => h.assetId), ['aapl', 'eur']);
    });
  });

  group('computeHoldingsByAssetAndContainer', () {
    Container holder(String id) =>
        Container(id: id, name: id, containerType: 'holder', deleted: false);

    test(
      'keys raw (unconverted) quantities by asset id then container id',
      () async {
        await hold('broker', 'aapl', '10');
        await hold('bank', 'eur', '500');

        final result = await computeHoldingsByAssetAndContainer(
          balanceEngine: balanceEngine,
          containers: [holder('broker'), holder('bank')],
        );

        expect(result['aapl'], equals({'broker': Decimal.fromInt(10)}));
        expect(result['eur'], equals({'bank': Decimal.fromInt(500)}));
      },
    );

    test(
      'sums the same asset across multiple containers, keyed separately',
      () async {
        await hold('broker1', 'aapl', '4');
        await hold('broker2', 'aapl', '6');

        final result = await computeHoldingsByAssetAndContainer(
          balanceEngine: balanceEngine,
          containers: [holder('broker1'), holder('broker2')],
        );

        expect(
          result['aapl'],
          equals({
            'broker1': Decimal.fromInt(4),
            'broker2': Decimal.fromInt(6),
          }),
        );
      },
    );

    test('a container passed in but never given any balance contributes '
        'nothing (not a zero entry)', () async {
      await hold('broker', 'aapl', '10');

      final result = await computeHoldingsByAssetAndContainer(
        balanceEngine: balanceEngine,
        containers: [holder('broker'), holder('empty')],
      );

      expect(result['aapl'], equals({'broker': Decimal.fromInt(10)}));
      expect(
        result.values.any((byContainer) => byContainer.containsKey('empty')),
        isFalse,
      );
    });

    test(
      'an asset with no holdings anywhere is simply absent from the result',
      () async {
        final result = await computeHoldingsByAssetAndContainer(
          balanceEngine: balanceEngine,
          containers: [holder('broker')],
        );
        expect(result, isEmpty);
      },
    );
  });
}

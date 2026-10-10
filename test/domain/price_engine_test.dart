import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart';
import 'package:moopro/domain/price_engine.dart';

void main() {
  late DomainCacheDatabase db;
  late PriceEngine engine;

  setUp(() {
    db = DomainCacheDatabase(NativeDatabase.memory());
    engine = PriceEngine(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertSnapshot({
    required String id,
    required String assetId,
    required DateTime date,
    required String price,
    required String currencyAssetId,
  }) {
    return db
        .into(db.priceSnapshots)
        .insert(
          PriceSnapshotsCompanion.insert(
            id: id,
            assetId: assetId,
            date: date,
            price: price,
            currencyAssetId: currencyAssetId,
            source: 'manual',
          ),
        );
  }

  group('latestPrice', () {
    test('the same asset in both slots returns 1 without a query', () async {
      expect(
        await engine.latestPrice('aapl', 'aapl', DateTime.utc(2026, 1, 1)),
        equals(Decimal.one),
      );
    });

    test(
      'no snapshot for the pair returns null, never a guessed 1:1',
      () async {
        expect(
          await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 1)),
          isNull,
        );
      },
    );

    test('an exact-date snapshot is returned', () async {
      await insertSnapshot(
        id: 's1',
        assetId: 'aapl',
        date: DateTime.utc(2026, 1, 5),
        price: '172.34',
        currencyAssetId: 'eur',
      );
      expect(
        await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 5)),
        equals(Decimal.parse('172.34')),
      );
    });

    test(
      'the latest snapshot at or before asOf wins, ignoring later ones',
      () async {
        await insertSnapshot(
          id: 's1',
          assetId: 'aapl',
          date: DateTime.utc(2026, 1, 1),
          price: '170.00',
          currencyAssetId: 'eur',
        );
        await insertSnapshot(
          id: 's2',
          assetId: 'aapl',
          date: DateTime.utc(2026, 1, 10),
          price: '172.34',
          currencyAssetId: 'eur',
        );
        await insertSnapshot(
          id: 's3',
          assetId: 'aapl',
          date: DateTime.utc(2026, 1, 20),
          price: '180.00',
          currencyAssetId: 'eur',
        );

        expect(
          await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 15)),
          equals(Decimal.parse('172.34')),
        );
      },
    );

    test('a date before every snapshot returns null', () async {
      await insertSnapshot(
        id: 's1',
        assetId: 'aapl',
        date: DateTime.utc(2026, 1, 10),
        price: '172.34',
        currencyAssetId: 'eur',
      );
      expect(
        await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 1)),
        isNull,
      );
    });

    test('a deleted snapshot is ignored', () async {
      await db
          .into(db.priceSnapshots)
          .insert(
            PriceSnapshotsCompanion.insert(
              id: 's1',
              assetId: 'aapl',
              date: DateTime.utc(2026, 1, 5),
              price: '172.34',
              currencyAssetId: 'eur',
              source: 'manual',
              deleted: const Value(true),
            ),
          );
      expect(
        await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 5)),
        isNull,
      );
    });

    test('only matches the exact (assetId, inAssetId) pair — a snapshot in '
        'a different currency is not returned', () async {
      await insertSnapshot(
        id: 's1',
        assetId: 'aapl',
        date: DateTime.utc(2026, 1, 5),
        price: '150.00',
        currencyAssetId: 'usd',
      );
      expect(
        await engine.latestPrice('aapl', 'eur', DateTime.utc(2026, 1, 5)),
        isNull,
      );
    });
  });
}

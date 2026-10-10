import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/api/api_client.dart';
import 'package:moopro/api/auth_api.dart';
import 'package:moopro/api/models.dart';
import 'package:moopro/api/vault_api.dart';
import 'package:moopro/auth/vault_session.dart';
import 'package:moopro/crypto/local_unlock_store.dart';
import 'package:moopro/crypto/local_vault_key_material_store.dart';
import 'package:moopro/crypto/vault_crypto.dart';
import 'package:moopro/db/database.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/balance_engine.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/widgets/due_recurring_occurrences_dialog.dart';
import 'package:moopro/domain/calendar_date.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];
  final List<List<DueRecurringOccurrence>> applyCalls = [];
  final List<List<DueRecurringOccurrence>> skipCalls = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);

  @override
  Future<void> skipDueRecurringOccurrences(
    List<DueRecurringOccurrence> occurrences,
  ) async {
    skipCalls.add(occurrences);
  }

  @override
  Future<void> applyDueRecurringOccurrences(
    List<DueRecurringOccurrence> occurrences,
  ) async {
    applyCalls.add(occurrences);
  }
}

class _FixedDekVaultSession extends VaultSessionManager {
  final Uint8List _dek;
  _FixedDekVaultSession(this._dek)
    : super(
        authApi: AuthApi(ApiClient()),
        localUnlockStore: LocalUnlockStore(),
        localVaultKeyMaterialStore: LocalVaultKeyMaterialStore(
          AppDatabase(NativeDatabase.memory()),
        ),
      );
  @override
  Uint8List? get currentDek => _dek;
}

class _VaultApiStub extends VaultApi {
  _VaultApiStub() : super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async =>
      const [];

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async => const [];
}

RecurringTransactionTemplate _template({required String id, String? note}) {
  final quantity = Decimal.parse('800');
  return RecurringTransactionTemplate(
    id: id,
    kind: TransactionKind.expense,
    legOut: RecurringLeg(
      containerId: 'bank',
      assetId: 'eur',
      quantity: quantity,
    ),
    legIn: RecurringLeg(
      containerId: externalHolderContainerId,
      assetId: 'eur',
      quantity: quantity,
    ),
    budgetLegOut: RecurringLeg(
      containerId: 'budget',
      assetId: 'eur',
      quantity: quantity,
    ),
    budgetLegIn: RecurringLeg(
      containerId: externalBudgetContainerId,
      assetId: 'eur',
      quantity: quantity,
    ),
    note: note,
    rule: RecurrenceRule(
      startDate: CalendarDate(2026, 1, 1),
      unit: RecurrenceUnit.month,
      interval: 1,
    ),
  );
}

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;

  setUp(() {
    syncDb = AppDatabase(NativeDatabase.memory());
    cacheDb = ldb.DomainCacheDatabase(NativeDatabase.memory());
    repo = _FakeDomainRepository(
      syncDb: syncDb,
      cacheDb: cacheDb,
      syncEngine: SyncEngine(db: syncDb, vaultApi: _VaultApiStub()),
      balanceEngine: BalanceEngine(cacheDb),
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
    repo.containers = const [
      ldb.Container(
        id: 'bank',
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
      ldb.Container(
        id: 'budget',
        name: 'Housing',
        containerType: 'budget',
        deleted: false,
      ),
    ];
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> pumpWithButton(
    WidgetTester tester,
    List<DueRecurringOccurrence> occurrences,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () =>
                  showDueRecurringOccurrencesDialog(context, occurrences),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  List<DueRecurringOccurrence> rentOccurrences(int months) {
    final rent = _template(id: 'rent', note: 'Rent');
    return [
      for (var m = 1; m <= months; m++)
        DueRecurringOccurrence(
          template: rent,
          occurrenceDate: CalendarDate(2026, m, 1),
        ),
    ];
  }

  testWidgets('lists each occurrence with its date, preferring the note over '
      'the container summary', (tester) async {
    await pumpWithButton(tester, rentOccurrences(3));

    expect(find.text('Recurring transactions due'), findsOneWidget);
    expect(find.textContaining('Rent'), findsNWidgets(3));
    expect(find.text('Bank · Housing'), findsNWidgets(3));
    expect(find.textContaining('2026-02-01'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(3));
  });

  testWidgets('unchecking an occurrence also unchecks later ones of the same '
      'template, and Apply selected posts only the rest', (tester) async {
    final occurrences = rentOccurrences(3);
    await pumpWithButton(tester, occurrences);

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Apply selected (1)'), findsOneWidget);

    await tester.tap(find.text('Apply selected (1)'));
    await tester.pumpAndSettle();

    expect(
      repo.applyCalls,
      equals([
        [occurrences[0]],
      ]),
    );
  });

  testWidgets('checking a later occurrence re-checks the earlier ones', (
    tester,
  ) async {
    await pumpWithButton(tester, rentOccurrences(3));

    await tester.tap(find.byType(Checkbox).at(0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Apply selected (0)'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pumpAndSettle();
    expect(find.text('Apply selected (2)'), findsOneWidget);
  });

  testWidgets('Apply all calls applyDueRecurringOccurrences with the exact '
      'list and dismisses the dialog', (tester) async {
    final rent = _template(id: 'rent', note: 'Rent');
    final occurrences = [
      DueRecurringOccurrence(
        template: rent,
        occurrenceDate: CalendarDate(2026, 1, 1),
      ),
    ];
    await pumpWithButton(tester, occurrences);

    await tester.tap(find.text('Apply all'));
    await tester.pumpAndSettle();

    expect(repo.applyCalls, equals([occurrences]));
    expect(find.text('Recurring transactions due'), findsNothing);
  });

  testWidgets('Skip for now dismisses without applying anything', (
    tester,
  ) async {
    final rent = _template(id: 'rent', note: 'Rent');
    final occurrences = [
      DueRecurringOccurrence(
        template: rent,
        occurrenceDate: CalendarDate(2026, 1, 1),
      ),
    ];
    await pumpWithButton(tester, occurrences);

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(repo.applyCalls, isEmpty);
    expect(find.text('Recurring transactions due'), findsNothing);
  });

  testWidgets('Skip selected confirms, then skips only the checked '
      'occurrences without applying', (tester) async {
    final occurrences = rentOccurrences(3);
    await pumpWithButton(tester, occurrences);

    await tester.tap(find.byType(Checkbox).at(2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip selected (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Skip selected occurrences?'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repo.skipCalls, equals([occurrences.sublist(0, 2)]));
    expect(repo.applyCalls, isEmpty);
    expect(find.text('Recurring transactions due'), findsNothing);
  });

  testWidgets('cancelling the skip confirmation changes nothing', (
    tester,
  ) async {
    await pumpWithButton(tester, rentOccurrences(1));

    await tester.tap(find.text('Skip selected (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.skipCalls, isEmpty);
    expect(find.text('Recurring transactions due'), findsOneWidget);
  });
}

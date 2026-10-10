import 'dart:typed_data';

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
import 'package:moopro/domain/models.dart'
    show externalBudgetContainerId, externalHolderContainerId;
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/recurring_template_form_screen.dart';
import 'package:moopro/screens/recurring_transactions_screen.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/domain/calendar_date.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.RecurringTransactionTemplate> templates = [];
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];
  final List<(String, bool)> setActiveCalls = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<List<ldb.RecurringTransactionTemplate>> watchRecurringTemplates() =>
      Stream.value(templates);

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Transaction>> watchTransactions() => Stream.value(const []);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);

  @override
  Future<void> setRecurringTemplateActive(String id, bool active) async {
    setActiveCalls.add((id, active));
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

const _eurId = 'eur00000000000';
const _bankId = 'bank000000000';
const _budgetId = 'budget00000000';

ldb.Asset _eur() => const ldb.Asset(
  id: _eurId,
  kind: 'fiat',
  symbol: 'EUR',
  name: 'Euro',
  deleted: false,
);

ldb.RecurringTransactionTemplate _expenseTemplate({
  required String id,
  bool active = true,
  String? note,
}) => ldb.RecurringTransactionTemplate(
  id: id,
  kind: 'expense',
  legOutContainerId: _bankId,
  legOutAssetId: _eurId,
  legOutQuantity: '800',
  legInContainerId: externalHolderContainerId,
  legInAssetId: _eurId,
  legInQuantity: '800',
  budgetLegOutContainerId: _budgetId,
  budgetLegOutAssetId: _eurId,
  budgetLegOutQuantity: '800',
  budgetLegInContainerId: externalBudgetContainerId,
  budgetLegInAssetId: _eurId,
  budgetLegInQuantity: '800',
  note: note,
  tags: '[]',
  ruleUnit: 'month',
  ruleInterval: 1,
  ruleStartDate: CalendarDate(2026, 1, 1),
  active: active,
  deleted: false,
);

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
    repo.assets = [_eur()];
    repo.containers = const [
      ldb.Container(
        id: _bankId,
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
      ldb.Container(
        id: _budgetId,
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

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: RecurringTransactionsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty state shows a placeholder, not a blank screen', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('No recurring transactions yet.'), findsOneWidget);
  });

  testWidgets(
    'an active template renders under Active with its note, amount and '
    'recurrence',
    (tester) async {
      repo.templates = [_expenseTemplate(id: 'tpl1', note: 'Rent')];

      await pump(tester);

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Paused'), findsNothing);
      expect(find.textContaining('Rent'), findsOneWidget);
      expect(find.text('Bank · Housing'), findsOneWidget);
      expect(find.text('−800.00 EUR'), findsOneWidget);
      expect(find.textContaining('every 1 month'), findsOneWidget);
    },
  );

  testWidgets('a paused template renders under Paused, not Active', (
    tester,
  ) async {
    repo.templates = [
      _expenseTemplate(id: 'tpl1', active: false, note: 'Rent'),
    ];

    await pump(tester);

    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Active'), findsNothing);
  });

  testWidgets('tapping the pause/resume icon calls setRecurringTemplateActive '
      'with the toggled value', (tester) async {
    repo.templates = [_expenseTemplate(id: 'tpl1', note: 'Rent')];

    await pump(tester);

    await tester.tap(find.byIcon(Icons.pause_circle_outline));
    await tester.pumpAndSettle();

    expect(repo.setActiveCalls, equals([('tpl1', false)]));
  });

  testWidgets(
    'tapping the FAB opens the create form with only the four supported '
    'kinds (no Trade)',
    (tester) async {
      await pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('New recurring'), findsOneWidget);
      expect(find.text('Income'), findsOneWidget);
      expect(find.text('Expense'), findsOneWidget);
      expect(find.text('Holder xfer'), findsOneWidget);
      expect(find.text('Budget xfer'), findsOneWidget);
      expect(find.text('Trade'), findsNothing);
    },
  );

  group('"Make recurring" prefill (from a posted transaction)', () {
    ldb.Transaction expenseTx({String? note, CalendarDate? date}) =>
        ldb.Transaction(
          id: 'tx1',
          postedAt: DateTime.utc(2026, 1, 31),
          effectiveDate: date ?? CalendarDate(2026, 1, 31),
          note: note,
          kind: 'expense',
          legOutContainerId: _bankId,
          legOutAssetId: _eurId,
          legOutQuantity: '800',
          legInContainerId: externalHolderContainerId,
          legInAssetId: _eurId,
          legInQuantity: '800',
          budgetLegOutContainerId: _budgetId,
          budgetLegOutAssetId: _eurId,
          budgetLegOutQuantity: '800',
          budgetLegInContainerId: externalBudgetContainerId,
          budgetLegInAssetId: _eurId,
          budgetLegInQuantity: '800',
          tags: '[]',
          manualOrderRank: 0,
          deleted: false,
        );

    Future<void> pumpForm(WidgetTester tester, ldb.Transaction tx) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: RecurringTemplateFormScreen(from: tx)),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('opens as "New recurring" with the transaction\'s fields', (
      tester,
    ) async {
      await pumpForm(tester, expenseTx(note: 'Rent'));

      expect(find.text('New recurring'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.widgetWithText(TextFormField, '800'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Rent'), findsOneWidget);
      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('Bank'), findsOneWidget);
      expect(find.text('Housing'), findsOneWidget);
    });

    testWidgets(
      'starts one month after the transaction (clamped), not on its date',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpForm(tester, expenseTx());

        expect(find.text('2026-02-28'), findsOneWidget);
        expect(find.text('2026-01-31'), findsNothing);
      },
    );

    testWidgets('copies the transaction\'s tags into the tag field', (
      tester,
    ) async {
      await pumpForm(tester, expenseTx().copyWith(tags: '["rent","home"]'));

      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('rent'), findsOneWidget);
      expect(find.text('home'), findsOneWidget);
    });

    testWidgets('a trade is not seeded (falls back to the blank default)', (
      tester,
    ) async {
      final trade = expenseTx().copyWith(kind: 'trade');
      await pumpForm(tester, trade);

      expect(find.widgetWithText(TextFormField, '800'), findsNothing);
    });
  });

  testWidgets('editing an existing template shows its tags', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: RecurringTemplateFormScreen(
            existing: _expenseTemplate(
              id: 'tpl1',
            ).copyWith(tags: '["subscription"]'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit recurring'), findsOneWidget);
    expect(find.text('subscription'), findsOneWidget);
  });
}

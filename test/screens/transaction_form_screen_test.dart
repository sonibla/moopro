import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
import 'package:moopro/domain/price_engine.dart';
import 'package:moopro/domain/transaction_kind_style.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/screens/transaction_form_screen.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/domain/calendar_date.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.Transaction> transactions = [];
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];

  ({
    String holderId,
    String budgetId,
    String assetOutId,
    Decimal quantityOut,
    String assetInId,
    Decimal quantityIn,
    List<String> tags,
  })?
  tradeCall;

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  @override
  Stream<List<ldb.Transaction>> watchTransactions() =>
      Stream.value(transactions);

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(const {});

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);

  @override
  Future<PullResult> syncNow({bool force = false}) async =>
      const PullResult(recordsApplied: 0, rollbackWarnings: []);

  @override
  Future<MoneyTransaction> recordTrade({
    String? id,
    required String holderId,
    required String budgetId,
    required String assetOutId,
    required Decimal quantityOut,
    required String assetInId,
    required Decimal quantityIn,
    required CalendarDate effectiveDate,
    DateTime? postedAt,
    String? note,
    List<String> tags = const [],
  }) async {
    tradeCall = (
      holderId: holderId,
      budgetId: budgetId,
      assetOutId: assetOutId,
      quantityOut: quantityOut,
      assetInId: assetInId,
      quantityIn: quantityIn,
      tags: tags,
    );
    return MoneyTransaction(
      id: id ?? 'new-trade',
      postedAt: postedAt ?? DateTime.now(),
      effectiveDate: effectiveDate,
      note: note,
      kind: TransactionKind.trade,
      legOut: TransactionLeg(
        containerId: holderId,
        assetId: assetOutId,
        quantity: quantityOut,
      ),
      legIn: TransactionLeg(
        containerId: holderId,
        assetId: assetInId,
        quantity: quantityIn,
      ),
      budgetLegOut: TransactionLeg(
        containerId: budgetId,
        assetId: assetOutId,
        quantity: quantityOut,
      ),
      budgetLegIn: TransactionLeg(
        containerId: budgetId,
        assetId: assetInId,
        quantity: quantityIn,
      ),
      tags: tags,
    );
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

class _NoopVaultApi extends VaultApi {
  _NoopVaultApi() : super(ApiClient());

  @override
  Future<List<VaultRecordResponse>> pull({required int sinceVersion}) async =>
      const [];

  @override
  Future<List<VaultRecordResponse>> push(
    List<VaultRecordUpsert> records,
  ) async => const [];
}

const _brokerId = 'broker0000000';
const _broker2Id = 'broker0000001';
const _broker3Id = 'broker0000002';
const _investmentsId = 'investments000';
const _eurId = 'eur00000000000';
const _usdId = 'usd00000000000';

ldb.Transaction _tradeRow({
  required String id,
  required DateTime date,
  required String holderId,
  required String assetOutId,
  required String assetInId,
  String? budgetId,
}) => ldb.Transaction(
  id: id,
  postedAt: date,
  effectiveDate: CalendarDate.fromDateTime(date),
  kind: TransactionKind.trade.name,
  legOutContainerId: holderId,
  legOutAssetId: assetOutId,
  legOutQuantity: '500',
  legInContainerId: holderId,
  legInAssetId: assetInId,
  legInQuantity: '540',
  budgetLegOutContainerId: budgetId,
  budgetLegOutAssetId: budgetId == null ? null : assetOutId,
  budgetLegOutQuantity: budgetId == null ? null : '500',
  budgetLegInContainerId: budgetId,
  budgetLegInAssetId: budgetId == null ? null : assetInId,
  budgetLegInQuantity: budgetId == null ? null : '540',
  tags: '[]',
  manualOrderRank: 0,
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
      syncEngine: SyncEngine(db: syncDb, vaultApi: _NoopVaultApi()),
      balanceEngine: BalanceEngine(cacheDb),
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
    repo.containers = [
      const ldb.Container(
        id: _brokerId,
        name: 'Broker',
        containerType: 'holder',
        deleted: false,
      ),
      const ldb.Container(
        id: _investmentsId,
        name: 'Investments',
        containerType: 'budget',
        deleted: false,
      ),
    ];
    repo.assets = [
      const ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      const ldb.Asset(
        id: _usdId,
        kind: 'fiat',
        symbol: 'USD',
        name: 'US Dollar',
        deleted: false,
      ),
    ];
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  Future<void> seedBalance(
    String containerId,
    String assetId,
    String quantity,
  ) async {
    final date = DateTime.utc(2026, 1, 1);
    await cacheDb
        .into(cacheDb.transactions)
        .insertOnConflictUpdate(
          ldb.TransactionsCompanion(
            id: Value('seed-$containerId-$assetId'),
            postedAt: Value(date),
            effectiveDate: Value(CalendarDate.fromDateTime(date)),
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
    await BalanceEngine(cacheDb).onTransactionChanged(
      oldLegs: null,
      newLegs: [MapEntry('external', assetId), MapEntry(containerId, assetId)],
      newDate: CalendarDate.fromDateTime(date),
    );
  }

  Future<void> pump(WidgetTester tester, {ldb.Transaction? existing}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          domainRepositoryProvider.overrideWithValue(repo),
          priceEngineProvider.overrideWithValue(PriceEngine(cacheDb)),
          balanceEngineProvider.overrideWithValue(BalanceEngine(cacheDb)),
        ],
        child: MaterialApp(
          home: TransactionFormScreen(
            existing: existing,
            initialKind: existing == null ? TransactionKind.trade : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selecting Trade shows the you-give/you-get sub-form instead '
      'of the single asset+amount field', (tester) async {
    await pump(tester);

    expect(find.text('YOU GIVE'), findsOneWidget);
    expect(find.text('YOU GET'), findsOneWidget);
    expect(find.text('Asset'), findsNothing);
    expect(find.text('Amount'), findsNothing);
  });

  testWidgets(
    'filling holder + budget + both sides and saving calls recordTrade '
    'with the right arguments',
    (tester) async {
      await pump(tester);

      await tester.tap(find.text('Select...').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broker'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select...'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Investments'));
      await tester.pumpAndSettle();

      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.first, '500');
      await tester.enterText(amountFields.at(1), '540');
      await tester.pumpAndSettle();

      expect(find.textContaining('Rate: 1 EUR'), findsOneWidget);

      await tester.tap(find.text('Save trade'));
      await tester.pumpAndSettle();

      expect(repo.tradeCall, isNotNull);
      expect(repo.tradeCall!.holderId, _brokerId);
      expect(repo.tradeCall!.budgetId, _investmentsId);
      expect(repo.tradeCall!.assetOutId, _eurId);
      expect(repo.tradeCall!.quantityOut, Decimal.parse('500'));
      expect(repo.tradeCall!.assetInId, _usdId);
      expect(repo.tradeCall!.quantityIn, Decimal.parse('540'));
    },
  );

  testWidgets(
    'leaving the budget unset blocks save — recordTrade is never called',
    (tester) async {
      await pump(tester);

      await tester.tap(find.text('Select...').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broker'));
      await tester.pumpAndSettle();

      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.first, '500');
      await tester.enterText(amountFields.at(1), '540');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save trade'));
      await tester.pumpAndSettle();

      expect(repo.tradeCall, isNull);
    },
  );

  testWidgets('the swap button exchanges both sides\' asset and amount', (
    tester,
  ) async {
    await pump(tester);

    final amountFields = find.byType(TextFormField);
    await tester.enterText(amountFields.first, '500');
    await tester.enterText(amountFields.at(1), '540');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pumpAndSettle();

    final fieldsAfter = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fieldsAfter[0].controller!.text, '540');
    expect(fieldsAfter[1].controller!.text, '500');
  });

  testWidgets('editing an existing (budgeted) trade pre-fills holder, '
      'budget, both assets, and both amounts (no read-only banner)', (
    tester,
  ) async {
    final existing = _tradeRow(
      id: 'tx1',
      date: DateTime(2026, 1, 10),
      holderId: _brokerId,
      assetOutId: _eurId,
      assetInId: _usdId,
      budgetId: _investmentsId,
    );
    repo.transactions = [existing];

    await pump(tester, existing: existing);

    expect(find.text('Broker'), findsOneWidget);
    expect(find.text('Investments'), findsOneWidget);
    expect(find.textContaining('overwrite'), findsNothing);
    final fields = tester
        .widgetList<TextFormField>(find.byType(TextFormField))
        .toList();
    expect(fields[0].controller!.text, '500');
    expect(fields[1].controller!.text, '540');

    await tester.tap(find.text('Save trade'));
    await tester.pumpAndSettle();

    expect(repo.tradeCall!.budgetId, _investmentsId);
    expect(repo.tradeCall!.quantityOut, Decimal.parse('500'));
    expect(repo.tradeCall!.quantityIn, Decimal.parse('540'));
  });

  testWidgets('editing an existing unbudgeted trade (pre-existing data '
      'from before trade required a budget) leaves Budget empty and '
      'blocks save until one is picked', (tester) async {
    final existing = _tradeRow(
      id: 'tx1',
      date: DateTime(2026, 1, 10),
      holderId: _brokerId,
      assetOutId: _eurId,
      assetInId: _usdId,
    );
    repo.transactions = [existing];

    await pump(tester, existing: existing);

    expect(find.text('Broker'), findsOneWidget);
    expect(find.text('Select...'), findsOneWidget);

    await tester.tap(find.text('Save trade'));
    await tester.pumpAndSettle();
    expect(repo.tradeCall, isNull);

    await tester.tap(find.text('Select...'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Investments'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save trade'));
    await tester.pumpAndSettle();
    expect(repo.tradeCall!.budgetId, _investmentsId);
  });

  group('trade holder/budget eligibility', () {
    testWidgets(
      'typing a give amount autofills the sole eligible holder and budget',
      (tester) async {
        await seedBalance(_brokerId, _eurId, '1000');
        await seedBalance(_investmentsId, _eurId, '1000');
        await pump(tester);

        expect(find.text('Select...'), findsNWidgets(2));

        final amountFields = find.byType(TextFormField);
        await tester.enterText(amountFields.first, '500');
        await tester.pumpAndSettle();

        expect(find.text('Broker'), findsOneWidget);
        expect(find.text('Investments'), findsOneWidget);
        expect(find.text('Select...'), findsNothing);
      },
    );

    testWidgets(
      'two eligible holders restrict the picker to just those two, with no '
      'autofill — a third, ineligible holder is excluded',
      (tester) async {
        repo.containers = [
          ...repo.containers,
          const ldb.Container(
            id: _broker2Id,
            name: 'Broker 2',
            containerType: 'holder',
            deleted: false,
          ),
          const ldb.Container(
            id: _broker3Id,
            name: 'Broker 3',
            containerType: 'holder',
            deleted: false,
          ),
        ];
        await seedBalance(_brokerId, _eurId, '1000');
        await seedBalance(_broker2Id, _eurId, '1000');
        await pump(tester);

        final amountFields = find.byType(TextFormField);
        await tester.enterText(amountFields.first, '500');
        await tester.pumpAndSettle();

        expect(find.text('Broker'), findsNothing);
        expect(find.text('Broker 2'), findsNothing);

        await tester.tap(find.text('Select...').first);
        await tester.pumpAndSettle();

        expect(find.text('Broker'), findsOneWidget);
        expect(find.text('Broker 2'), findsOneWidget);
        expect(find.text('Broker 3'), findsNothing);
      },
    );
  });

  group('responsive chrome', () {
    testWidgets('mobile (<900px) shows an AppBar with a checkmark save action '
        'and a sticky bottom Save bar', (tester) async {
      await pump(tester);

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save trade'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('desktop (≥900px) shows a centered card with its own close '
        'button instead of an AppBar', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            home: TransactionFormScreen(initialKind: TransactionKind.trade),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('New transaction'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save trade'), findsOneWidget);
    });
  });

  group('type tabs', () {
    testWidgets('one pill per kind; selecting a different one switches the '
        'Save button label', (tester) async {
      await pump(tester);
      expect(find.widgetWithText(FilledButton, 'Save trade'), findsOneWidget);

      for (final label in [
        'Income',
        'Expense',
        'Holder xfer',
        'Budget xfer',
        'Trade',
      ]) {
        expect(find.widgetWithText(ChoiceChip, label), findsOneWidget);
      }

      await tester.tap(find.widgetWithText(ChoiceChip, 'Income'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Save income'), findsOneWidget);
      expect(find.text('YOU GIVE'), findsNothing);
    });

    testWidgets('the type pills wrap instead of requiring a horizontal '
        'scroll to reach every kind', (tester) async {
      await pump(tester);

      expect(find.widgetWithText(ChoiceChip, 'Trade'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal,
        ),
        findsNothing,
      );
    });

    testWidgets('each pill shows its kind icon as an avatar, matching '
        "TransactionFilterBar's kind chips", (tester) async {
      await pump(tester);

      for (final kind in TransactionKind.values) {
        final chip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, TransactionKindStyle.labels[kind]!),
        );
        final avatar = chip.avatar;
        expect(avatar, isA<Icon>());
        expect((avatar as Icon).icon, TransactionKindStyle.iconOf(kind));
      }
    });
  });

  group('showTransactionForm', () {
    Future<void> pumpOpenButton(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTransactionForm(
                    context,
                    initialKind: TransactionKind.trade,
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('at <900px, pushes a full-screen page — not a dialog', (
      tester,
    ) async {
      await pumpOpenButton(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('at >=900px, opens a real Dialog that dismisses on tap-outside '
        '(regression: an earlier version faked the desktop modal with a '
        "hand-painted backdrop that wasn't actually a barrier route, so "
        "tapping outside it did nothing)", (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpOpenButton(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('New transaction'), findsOneWidget);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
      expect(find.text('New transaction'), findsNothing);
    });

    testWidgets('at >=900px, Escape dismisses the dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpOpenButton(tester);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    group('unsaved changes confirmation', () {
      Future<void> openAndDirty(WidgetTester tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpOpenButton(tester);
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).last, 'grocery run');
        await tester.pumpAndSettle();
      }

      testWidgets(
        'tapping outside the dialog barrier with unsaved changes prompts '
        'instead of closing immediately (regression: PopScope.canPop is only '
        "evaluated at build time, and typing into a field didn't trigger a "
        'rebuild, so the stale not-dirty canPop let the pop through)',
        (tester) async {
          await openAndDirty(tester);

          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          expect(find.text('New transaction'), findsOneWidget);
          expect(find.text('Discard changes?'), findsOneWidget);
        },
      );

      testWidgets(
        "'Keep editing' dismisses the prompt and leaves the form open with "
        'the typed text intact',
        (tester) async {
          await openAndDirty(tester);
          await tester.tapAt(const Offset(10, 10));
          await tester.pumpAndSettle();

          await tester.tap(find.text('Keep editing'));
          await tester.pumpAndSettle();

          expect(find.text('Discard changes?'), findsNothing);
          expect(find.text('grocery run'), findsOneWidget);
        },
      );

      testWidgets("'Discard' closes both the prompt and the form", (
        tester,
      ) async {
        await openAndDirty(tester);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Discard'));
        await tester.pumpAndSettle();

        expect(find.text('Discard changes?'), findsNothing);
        expect(find.text('New transaction'), findsNothing);
      });

      testWidgets(
        'Escape with unsaved changes prompts instead of closing immediately',
        (tester) async {
          await openAndDirty(tester);

          await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          await tester.pumpAndSettle();

          expect(find.text('New transaction'), findsOneWidget);
          expect(find.text('Discard changes?'), findsOneWidget);
        },
      );

      testWidgets(
        "the wide dialog's own Cancel button also prompts (regression: it "
        'called Navigator.pop() directly, which — unlike the barrier/Escape/ '
        'back-gesture paths that go through Navigator.maybePop — PopScope '
        'does not gate at all)',
        (tester) async {
          await openAndDirty(tester);

          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();

          expect(find.text('New transaction'), findsOneWidget);
          expect(find.text('Discard changes?'), findsOneWidget);
        },
      );
    });
  });

  group('trade autofill', () {
    Future<void> seedPrice({
      required String fromAssetId,
      required String toAssetId,
      required String price,
    }) {
      return cacheDb
          .into(cacheDb.priceSnapshots)
          .insert(
            ldb.PriceSnapshotsCompanion.insert(
              id: 'snap1',
              assetId: fromAssetId,
              date: DateTime(2000, 1, 1),
              price: price,
              currencyAssetId: toAssetId,
              source: 'manual',
            ),
          );
    }

    testWidgets(
      'typing the give amount fills the empty get amount from a known '
      'price snapshot',
      (tester) async {
        await seedPrice(fromAssetId: _eurId, toAssetId: _usdId, price: '1.10');
        await pump(tester);

        final amountFields = find.byType(TextFormField);
        await tester.enterText(amountFields.first, '100');
        await tester.pumpAndSettle();

        final getField = tester.widget<TextFormField>(amountFields.at(1));
        expect(getField.controller!.text, '110.00');
      },
    );

    testWidgets('never overwrites a get amount the user already typed', (
      tester,
    ) async {
      await seedPrice(fromAssetId: _eurId, toAssetId: _usdId, price: '1.10');
      await pump(tester);

      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.at(1), '999');
      await tester.enterText(amountFields.first, '100');
      await tester.pumpAndSettle();

      final getField = tester.widget<TextFormField>(amountFields.at(1));
      expect(getField.controller!.text, '999');
    });

    testWidgets('with no matching price snapshot, nothing is auto-filled', (
      tester,
    ) async {
      await pump(tester);

      final amountFields = find.byType(TextFormField);
      await tester.enterText(amountFields.first, '100');
      await tester.pumpAndSettle();

      final getField = tester.widget<TextFormField>(amountFields.at(1));
      expect(getField.controller!.text, isEmpty);
    });
  });

  group('asset picker', () {
    testWidgets(
      'tapping an asset chip opens the sectioned asset picker (not a bare '
      'dropdown menu) and updates the selection',
      (tester) async {
        await pump(tester);

        await tester.tap(find.text('EUR'));
        await tester.pumpAndSettle();

        expect(find.text('FIAT CURRENCY (2)'), findsOneWidget);
        expect(find.byType(DropdownMenuItem<String>), findsNothing);

        await tester.tap(find.widgetWithText(ListTile, 'USD'));
        await tester.pumpAndSettle();

        final amountFields = find.byType(TextFormField);
        await tester.enterText(amountFields.first, '500');
        await tester.enterText(amountFields.at(1), '540');
        await tester.pumpAndSettle();

        expect(find.textContaining('Rate: 1 USD'), findsOneWidget);
      },
    );
  });

  group('posted-at field', () {
    testWidgets('is a proper labeled, tappable date+time field rather than '
        'a bare caption', (tester) async {
      await pump(tester);

      expect(find.text('Posted'), findsOneWidget);
      await tester.tap(
        find.ancestor(of: find.text('Posted'), matching: find.byType(InkWell)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);
    });
  });

  group('wide layout', () {
    testWidgets('does not overflow, and the fields Scrollbar paints without '
        'throwing, when the card is taller than the viewport (regression: '
        'an earlier version wrapped the whole card in the scroll instead of '
        'nesting it inside, and a later fix for that dropped the Scrollbar\'s '
        'explicit controller, which crashes on desktop/web where the '
        'always-visible Scrollbar needs an attached ScrollPosition to paint)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [domainRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(
              home: TransactionFormScreen(initialKind: TransactionKind.trade),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('YOU GIVE'), findsOneWidget);

        await tester.drag(find.text('YOU GIVE'), const Offset(0, -100));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}

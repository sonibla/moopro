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
import 'package:moopro/domain/calendar_date.dart';
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/balance_chart_card.dart';
import 'package:moopro/widgets/container_explorer/container_breakdown_card.dart';
import 'package:moopro/widgets/pie_chart_card.dart';
import 'package:moopro/screens/budgets_screen.dart';
import 'package:moopro/sync/sync_engine.dart';

import '../domain/balance_chart_rows.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];
  List<ldb.Transaction> transactions = [];
  List<ldb.PriceSnapshot> priceSnapshots = [];
  List<ldb.RecurringTransactionTemplate> templates = [];

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
  Stream<List<ldb.PriceSnapshot>> watchPriceSnapshots() =>
      Stream.value(priceSnapshots);

  @override
  Stream<List<ldb.RecurringTransactionTemplate>> watchRecurringTemplates() =>
      Stream.value(templates);

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  @override
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(const {});

  @override
  Stream<SyncCounts> watchSyncCounts() =>
      Stream.value(const SyncCounts(pending: 0, conflicted: 0));

  String? defaultCurrencyAssetId;

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(
    defaultCurrencyAssetId == null
        ? null
        : ldb.Setting(id: id, value: defaultCurrencyAssetId!, deleted: false),
  );
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
const _btcId = 'btc00000000000';
const _usdId = 'usd00000000000';

const _pieHeaderAllowance = 16.0;

void main() {
  late AppDatabase syncDb;
  late ldb.DomainCacheDatabase cacheDb;
  late _FakeDomainRepository repo;
  late BalanceEngine balanceEngine;

  setUp(() {
    syncDb = AppDatabase(NativeDatabase.memory());
    cacheDb = ldb.DomainCacheDatabase(NativeDatabase.memory());
    balanceEngine = BalanceEngine(cacheDb);
    repo = _FakeDomainRepository(
      syncDb: syncDb,
      cacheDb: cacheDb,
      syncEngine: SyncEngine(db: syncDb, vaultApi: _VaultApiStub()),
      balanceEngine: balanceEngine,
      vaultSession: _FixedDekVaultSession(VaultCrypto.generateDek()),
    );
  });

  tearDown(() async {
    await syncDb.close();
    await cacheDb.close();
  });

  final day = CalendarDate(2025, 1, 1);
  var seq = 0;
  void hold(String container, String asset, String qty) {
    repo.transactions = [
      ...repo.transactions,
      incomeRow(
        'tx${seq++}',
        day,
        budget: container,
        asset: asset,
        amount: qty,
        holderAfter: qty,
      ),
    ];
  }

  void price(String asset, String value) {
    repo.priceSnapshots = [
      ...repo.priceSnapshots,
      for (final a in repo.assets)
        if (a.id != asset) priceRow(asset, day, value, currency: a.id),
    ];
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [domainRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: BudgetsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('converts a non-home asset into the default display asset '
      'instead of ignoring it', (tester) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'crypto',
        name: 'Crypto',
        containerType: 'budget',
        deleted: false,
      ),
    ];
    hold('crypto', _btcId, '0.5');
    price(_btcId, '60000');

    await pump(tester);

    expect(find.textContaining('30000.00 EUR'), findsWidgets);
  });

  testWidgets(
    'the persisted default-currency setting wins over "first asset in '
    'the vault" when set',
    (tester) async {
      repo.assets = const [
        ldb.Asset(
          id: _eurId,
          kind: 'fiat',
          symbol: 'EUR',
          name: 'Euro',
          deleted: false,
        ),
        ldb.Asset(
          id: _usdId,
          kind: 'fiat',
          symbol: 'USD',
          name: 'US Dollar',
          deleted: false,
        ),
        ldb.Asset(
          id: _btcId,
          kind: 'crypto',
          symbol: 'BTC',
          name: 'Bitcoin',
          deleted: false,
        ),
      ];
      repo.containers = const [
        ldb.Container(
          id: 'crypto',
          name: 'Crypto',
          containerType: 'budget',
          deleted: false,
        ),
      ];
      hold('crypto', _btcId, '0.5');
      price(_btcId, '60000');
      repo.defaultCurrencyAssetId = _usdId;

      await pump(tester);

      expect(find.textContaining('30000.00 USD'), findsWidgets);
      expect(find.textContaining('EUR'), findsNothing);
    },
  );

  testWidgets('the display-asset selector switches which asset totals are '
      'converted into', (tester) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _usdId,
        kind: 'fiat',
        symbol: 'USD',
        name: 'US Dollar',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'savings',
        name: 'Savings',
        containerType: 'budget',
        deleted: false,
      ),
    ];
    hold('savings', _eurId, '100');
    price(_eurId, '1.1');

    await pump(tester);
    expect(find.textContaining('100.00 EUR'), findsWidgets);
    expect(find.text('Convert to EUR'), findsOneWidget);

    await tester.tap(find.text('Convert to EUR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD — US Dollar'));
    await tester.pumpAndSettle();

    expect(find.text('Convert to USD'), findsOneWidget);
    expect(find.textContaining('110.00 USD'), findsWidgets);
  });

  testWidgets('filtering to a single asset shows raw units (not converted) '
      'and a removable filter chip, clearing back to "All assets"', (
    tester,
  ) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'crypto',
        name: 'Crypto',
        containerType: 'budget',
        deleted: false,
      ),
      ldb.Container(
        id: 'savings',
        name: 'Savings',
        containerType: 'budget',
        deleted: false,
      ),
    ];
    hold('crypto', _btcId, '0.5');
    hold('savings', _eurId, '1000');
    price(_btcId, '60000');

    await pump(tester);
    expect(find.text('All assets'), findsOneWidget);

    await tester.tap(find.text('All assets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BTC — Bitcoin'));
    await tester.pumpAndSettle();

    expect(find.text('Asset: BTC'), findsOneWidget);
    expect(find.textContaining('0.50000000 BTC'), findsWidgets);
    expect(find.textContaining('Savings'), findsNothing);
    expect(find.text('filtered'), findsOneWidget);

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('All assets'), findsOneWidget);
    expect(find.text('Asset: BTC'), findsNothing);
  });

  testWidgets('an asset with no known price shows up in the "Actual assets '
      'held" panel with a "no known price" note rather than being dropped', (
    tester,
  ) async {
    repo.assets = const [
      ldb.Asset(
        id: _eurId,
        kind: 'fiat',
        symbol: 'EUR',
        name: 'Euro',
        deleted: false,
      ),
      ldb.Asset(
        id: _btcId,
        kind: 'crypto',
        symbol: 'BTC',
        name: 'Bitcoin',
        deleted: false,
      ),
    ];
    repo.containers = const [
      ldb.Container(
        id: 'crypto',
        name: 'Crypto',
        containerType: 'budget',
        deleted: false,
      ),
    ];
    hold('crypto', _btcId, '0.5');

    await pump(tester);

    expect(find.text('ACTUAL ASSETS HELD'), findsOneWidget);
    expect(find.text('no known price'), findsOneWidget);
    expect(
      find.byTooltip(
        "Contains an asset with no known price — its value isn't included in this total",
      ),
      findsOneWidget,
    );
  });

  const eurAsset = ldb.Asset(
    id: _eurId,
    kind: 'fiat',
    symbol: 'EUR',
    name: 'Euro',
    deleted: false,
  );
  const savings = ldb.Container(
    id: 'savings',
    name: 'Savings',
    containerType: 'budget',
    deleted: false,
  );
  const travel = ldb.Container(
    id: 'travel',
    name: 'Travel',
    containerType: 'budget',
    deleted: false,
  );

  testWidgets('the as-of date defaults to today; picking a later date marks '
      'the page as forecast and the menu\'s "Today" resets it', (tester) async {
    repo.assets = const [eurAsset];
    repo.containers = const [savings];
    hold('savings', _eurId, '100');
    await pump(tester);

    expect(find.textContaining('· forecast'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('asOfChip')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<MenuItemButton>(find.byKey(const ValueKey('asOfMenuToday')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const ValueKey('asOfMenuPick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.text('15'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('· forecast'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('asOfChip')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('asOfMenuToday')));
    await tester.pumpAndSettle();
    expect(find.textContaining('· forecast'), findsNothing);
  });

  testWidgets('selecting a budget card focuses the whole page on it: header, '
      'balance chart title and its transactions', (tester) async {
    repo.assets = const [eurAsset];
    repo.containers = const [savings, travel];
    hold('savings', _eurId, '100');
    hold('travel', _eurId, '50');
    await pump(tester);

    expect(find.text('All budgets'), findsOneWidget);
    expect(find.text('Transactions'), findsNothing);
    bool enabled(String key) =>
        tester.widget<IconButton>(find.byKey(ValueKey(key))).onPressed != null;
    for (final k in ['focusBack', 'openTransactions', 'editFocusedContainer']) {
      expect(enabled(k), isFalse, reason: k);
    }
    expect(find.text('Root'), findsOneWidget);
    final rootContentTop = tester.getTopLeft(find.text('All budgets')).dy;
    final rootChipTop = tester
        .getTopLeft(find.byKey(const ValueKey('asOfChip')))
        .dy;

    final card = find.textContaining('Savings ·');
    await tester.ensureVisible(card.first);
    await tester.pump();
    await tester.tap(card.first);
    await tester.pumpAndSettle();

    expect(find.text('Balance over time · Savings'), findsNothing);
    expect(find.text('Balance over time'), findsNothing);
    expect(find.text('By budget'), findsNothing);
    for (final k in ['focusBack', 'openTransactions', 'editFocusedContainer']) {
      expect(enabled(k), isTrue, reason: k);
    }
    expect(find.text('Root'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Savings').first).dy,
      closeTo(rootContentTop, 1),
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('asOfChip'))).dy,
      closeTo(rootChipTop, 1),
    );
    expect(find.text('All budgets'), findsNothing);
    expect(find.textContaining('100.00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('focusBack')));
    await tester.pumpAndSettle();
    expect(find.text('All budgets'), findsOneWidget);
    expect(enabled('focusBack'), isFalse);
  });

  testWidgets('the focused container\'s Transactions button opens the '
      'Transactions tab pre-filtered to it', (tester) async {
    repo.assets = const [eurAsset];
    repo.containers = const [savings, travel];
    hold('savings', _eurId, '100');
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('containerSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Savings').last);
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(BudgetsScreen)),
    );
    container.read(selectedTabProvider.notifier).state = 1;
    await tester.ensureVisible(find.byKey(const ValueKey('openTransactions')));
    await tester.tap(find.byKey(const ValueKey('openTransactions')));
    await tester.pump();

    expect(container.read(transactionFilterProvider).containerId, 'savings');
    expect(container.read(selectedTabProvider), transactionsTabIndex);
  });

  testWidgets('on a wide screen the pie sits beside a taller balance chart; '
      'on a narrow one it stacks below', (tester) async {
    repo.assets = const [eurAsset];
    repo.containers = const [savings];
    hold('savings', _eurId, '100');

    Future<void> at(double width) async {
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(width),
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: BudgetsScreen()),
        ),
      );
      await tester.pumpAndSettle();
    }

    await at(1500);
    Rect cardOf(Type t) => tester.getRect(
      find.descendant(of: find.byType(t), matching: find.byType(Card)).first,
    );
    final wideChart = cardOf(BalanceChartCard);
    final widePie = cardOf(PieChartCard);
    expect(widePie.left, greaterThanOrEqualTo(wideChart.right - 1));
    expect(widePie.top, closeTo(wideChart.top, 8));
    expect(wideChart.height, greaterThan(500));
    expect(widePie.top, closeTo(wideChart.top, 0.5));
    expect(widePie.height, closeTo(wideChart.height, 0.5));
    final wedgeArea = tester.getRect(
      find.byKey(const ValueKey('pieChartTapArea')),
    );
    expect(
      wedgeArea.center.dy,
      closeTo(widePie.top + (widePie.height + _pieHeaderAllowance) / 2, 40),
    );

    await at(800);
    final narrowChart = tester.getRect(find.byType(BalanceChartCard));
    final narrowPie = tester.getRect(find.byType(PieChartCard));
    expect(narrowPie.top, greaterThanOrEqualTo(narrowChart.bottom - 1));
    final narrowWedges = tester.getSize(
      find.byKey(const ValueKey('pieChartTapArea')),
    );
    expect(narrowWedges.width, lessThanOrEqualTo(320));
  });

  testWidgets('the pie card has a fixed height however many rows the '
      'Breakdown has, and the legend lives in the Breakdown', (tester) async {
    Future<Rect> pieRect(int budgets) async {
      repo.assets = const [eurAsset];
      repo.containers = [
        for (var i = 0; i < budgets; i++)
          ldb.Container(
            id: 'b$i',
            name: 'Budget $i',
            containerType: 'budget',
            deleted: false,
          ),
      ];
      repo.transactions = [];
      for (var i = 0; i < budgets; i++) {
        hold('b$i', _eurId, '${10 + i}');
      }
      tester.view.physicalSize = const Size(1500, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(budgets),
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(home: BudgetsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getRect(find.byType(PieChartCard));
    }

    final few = await pieRect(2);
    final many = await pieRect(9);
    expect(many.height, few.height);
    expect(
      find.descendant(
        of: find.byType(PieChartCard),
        matching: find.textContaining('Budget 1 ·'),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ContainerBreakdownCard),
        matching: find.textContaining('Budget 1 ·'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the Breakdown lists sub-budgets with a colored dot, share and '
      'a chevron to expand them', (tester) async {
    repo.assets = const [eurAsset];
    repo.containers = const [
      savings,
      ldb.Container(
        id: 'kid',
        name: 'Kid',
        containerType: 'budget',
        parentId: 'savings',
        deleted: false,
      ),
    ];
    hold('kid', _eurId, '40');
    hold('savings', _eurId, '60');
    await pump(tester);

    final breakdown = find.byType(ContainerBreakdownCard);
    expect(
      find.descendant(
        of: breakdown,
        matching: find.textContaining('Savings ·'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: breakdown, matching: find.textContaining('Kid ·')),
      findsNothing,
      reason: 'children collapsed',
    );

    await tester.ensureVisible(find.byIcon(Icons.expand_more).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: breakdown, matching: find.textContaining('Kid ·')),
      findsOneWidget,
    );
  });

  testWidgets(
    'the balance chart has no legend chips; the focused budget\'s own '
    'balance is an "Unassigned" row in the Breakdown',
    (tester) async {
      repo.assets = const [eurAsset];
      repo.containers = const [
        savings,
        ldb.Container(
          id: 'kid',
          name: 'Kid',
          containerType: 'budget',
          parentId: 'savings',
          deleted: false,
        ),
      ];
      hold('kid', _eurId, '40');
      hold('savings', _eurId, '60');
      await pump(tester);
      expect(
        find.byKey(const ValueKey('balance-legend-savings')),
        findsNothing,
      );

      final row = find.textContaining('Savings ·');
      await tester.ensureVisible(row.first);
      await tester.pump();
      await tester.tap(row.first);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('balance-legend-kid')), findsNothing);
      expect(
        find.descendant(
          of: find.byType(ContainerBreakdownCard),
          matching: find.textContaining('Unassigned'),
        ),
        findsOneWidget,
      );
    },
  );
}

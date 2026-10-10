import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:moopro/screens/transactions_screen.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/theme/app_scroll_behavior.dart';
import 'package:moopro/widgets/transfer_flow_chart.dart';
import 'package:moopro/domain/calendar_date.dart';

class _FakeDomainRepository extends DomainRepository {
  List<ldb.Transaction> transactions = [];
  List<ldb.Container> containers = [];
  List<ldb.Asset> assets = [];

  final List<Set<String>> deleteCalls = [];
  final List<String> singleDeleteCalls = [];
  final List<({List<ldb.Transaction> originals, CalendarDate effectiveDate})>
  copyCalls = [];

  _FakeDomainRepository({
    required super.syncDb,
    required super.cacheDb,
    required super.syncEngine,
    required super.balanceEngine,
    required super.vaultSession,
  });

  StreamController<List<ldb.Transaction>>? liveTransactions;

  @override
  Stream<List<ldb.Transaction>> watchTransactions() async* {
    yield transactions;
    final live = liveTransactions;
    if (live != null) yield* live.stream;
  }

  @override
  Stream<List<ldb.Container>> watchContainers() => Stream.value(containers);

  @override
  Stream<List<ldb.Asset>> watchAssets() => Stream.value(assets);

  Map<String, RecordSyncStatus> statuses = const {};

  @override
  Stream<Map<String, RecordSyncStatus>> watchRecordStatuses() =>
      Stream.value(statuses);

  @override
  Stream<ldb.Setting?> watchSetting(String id) => Stream.value(null);

  int syncNowCalls = 0;

  @override
  Future<PullResult> syncNow() async {
    syncNowCalls++;
    return const PullResult(recordsApplied: 0, rollbackWarnings: []);
  }

  @override
  Future<void> acknowledgeConflict(String id) async {}

  @override
  Future<void> deleteTransactions(Iterable<String> ids) async {
    deleteCalls.add(ids.toSet());
  }

  @override
  Future<void> deleteTransaction(String id) async {
    singleDeleteCalls.add(id);
  }

  @override
  Future<List<MoneyTransaction>> copyTransactions(
    List<ldb.Transaction> originals, {
    required CalendarDate effectiveDate,
    DateTime? postedAt,
  }) async {
    copyCalls.add((originals: originals, effectiveDate: effectiveDate));
    return const [];
  }

  @override
  Future<void> reorderTransactions(Map<String, int> newRankById) async {}
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

const _bankId = 'bank0000000000';
const _budgetId = 'budget00000000';
const _eurId = 'eur00000000000';

ldb.Transaction _incomeRow({
  required String id,
  required DateTime date,
  String? note,
}) => ldb.Transaction(
  id: id,
  postedAt: date,
  effectiveDate: CalendarDate.fromDateTime(date),
  note: note,
  kind: TransactionKind.income.name,
  legOutContainerId: externalHolderContainerId,
  legOutAssetId: _eurId,
  legOutQuantity: '100',
  legInContainerId: _bankId,
  legInAssetId: _eurId,
  legInQuantity: '100',
  budgetLegOutContainerId: externalBudgetContainerId,
  budgetLegOutAssetId: _eurId,
  budgetLegOutQuantity: '100',
  budgetLegInContainerId: _budgetId,
  budgetLegInAssetId: _eurId,
  budgetLegInQuantity: '100',
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

ldb.Transaction _holderTransferRow({
  required String id,
  required DateTime date,
  String? note,
  String to = _bankId,
}) => ldb.Transaction(
  id: id,
  postedAt: date,
  effectiveDate: CalendarDate.fromDateTime(date),
  note: note,
  kind: TransactionKind.holderTransfer.name,
  legOutContainerId: _bankId,
  legOutAssetId: _eurId,
  legOutQuantity: '10',
  legInContainerId: to,
  legInAssetId: _eurId,
  legInQuantity: '10',
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

ldb.Transaction _budgetTransferRow({
  required String id,
  required String from,
  required String to,
  required DateTime date,
  String quantity = '10',
  String? note,
}) => ldb.Transaction(
  id: id,
  postedAt: date,
  effectiveDate: CalendarDate.fromDateTime(date),
  note: note,
  kind: TransactionKind.budgetTransfer.name,
  legOutContainerId: from,
  legOutAssetId: _eurId,
  legOutQuantity: quantity,
  legInContainerId: to,
  legInAssetId: _eurId,
  legInQuantity: quantity,
  tags: '[]',
  manualOrderRank: 0,
  deleted: false,
);

ldb.Container _budget(String id, String name) =>
    ldb.Container(id: id, name: name, containerType: 'budget', deleted: false);

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
        id: _bankId,
        name: 'Bank',
        containerType: 'holder',
        deleted: false,
      ),
      const ldb.Container(
        id: _budgetId,
        name: 'Groceries',
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
        child: const MaterialApp(
          scrollBehavior: AppScrollBehavior(),
          home: Scaffold(body: TransactionsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state when there are no transactions', (
    tester,
  ) async {
    await pump(tester);
    expect(find.textContaining('No transactions yet'), findsOneWidget);
  });

  testWidgets(
    'lists created transactions and lets a kind filter narrow them down',
    (tester) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime.now(), note: 'Paycheck'),
        _holderTransferRow(
          id: 'tx2',
          date: DateTime.now(),
          note: 'Between accounts',
        ),
      ];

      await pump(tester);
      expect(find.textContaining('Paycheck'), findsOneWidget);
      expect(find.textContaining('Between accounts'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Income'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Paycheck'), findsOneWidget);
      expect(find.textContaining('Between accounts'), findsNothing);
    },
  );

  testWidgets('long-press enters selection mode; confirming delete calls '
      'DomainRepository.deleteTransactions with the selected id', (
    tester,
  ) async {
    repo.transactions = [
      _incomeRow(id: 'tx1', date: DateTime.now(), note: 'Paycheck'),
    ];
    await pump(tester);

    await tester.longPress(find.textContaining('Paycheck'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      repo.deleteCalls,
      equals([
        {'tx1'},
      ]),
    );
  });

  testWidgets('tapping the Select button enters selection mode with nothing '
      'selected, and it can be exited via the selection bar close button', (
    tester,
  ) async {
    repo.transactions = [
      _incomeRow(id: 'tx1', date: DateTime.now(), note: 'Paycheck'),
    ];
    await pump(tester);

    expect(find.text('0 selected'), findsNothing);
    await tester.tap(find.byIcon(Icons.checklist));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(2));

    await tester.tap(find.byTooltip('Cancel selection'));
    await tester.pumpAndSettle();

    expect(find.text('0 selected'), findsNothing);
    expect(find.byIcon(Icons.checklist), findsOneWidget);
  });

  testWidgets('long-press then copy opens the date dialog and calls '
      'DomainRepository.copyTransactions with the selected row', (
    tester,
  ) async {
    final tx = _incomeRow(id: 'tx1', date: DateTime.now(), note: 'Paycheck');
    repo.transactions = [tx];
    await pump(tester);

    await tester.longPress(find.textContaining('Paycheck'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Copy to date'));
    await tester.pumpAndSettle();
    expect(find.text('Copy 1 transaction'), findsOneWidget);

    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();

    expect(repo.copyCalls, hasLength(1));
    expect(repo.copyCalls.single.originals.map((r) => r.id), equals(['tx1']));
  });

  group('select all / day header', () {
    final today = DateTime.now();
    final older = today.subtract(const Duration(days: 10));

    List<ldb.Transaction> threeRows() => [
      _incomeRow(id: 'tx1', date: today, note: 'Paycheck'),
      _holderTransferRow(id: 'tx2', date: today, note: 'Between accounts'),
      _incomeRow(id: 'tx3', date: older, note: 'Old bonus'),
    ];

    testWidgets('"Select all (N)" selects every row, then toggles to '
        '"Deselect all"', (tester) async {
      repo.transactions = threeRows();
      await pump(tester);

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Select all (3)'), findsOneWidget);

      await tester.tap(find.byTooltip('Select all (3)'));
      await tester.pumpAndSettle();
      expect(find.text('3 selected'), findsOneWidget);
      expect(find.byTooltip('Deselect all'), findsOneWidget);

      await tester.tap(find.byTooltip('Deselect all'));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('"Select all" covers only the currently filtered rows', (
      tester,
    ) async {
      repo.transactions = threeRows();
      await pump(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Income'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Select all (2)'), findsOneWidget);
      await tester.tap(find.byTooltip('Select all (2)'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('a day header checkbox selects, then deselects, that day '
        'only, and shows indeterminate for a partial day', (tester) async {
      repo.transactions = threeRows();
      await pump(tester);
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();

      Checkbox box(int i) =>
          tester.widget<Checkbox>(find.byType(Checkbox).at(i));
      expect(box(0).value, isFalse);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(box(0).value, isTrue);
      expect(box(3).value, isFalse);

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(box(0).value, isNull);

      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.pumpAndSettle();
      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('long-pressing a day header enters selection mode with '
        'that day selected', (tester) async {
      repo.transactions = threeRows();
      await pump(tester);

      await tester.longPress(find.text('Today'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });
  });

  group('drag selection (mobile)', () {
    final today = DateTime.now();
    int selectedCount(WidgetTester tester) {
      final text = tester
          .widgetList<Text>(find.textContaining(' selected'))
          .map((t) => t.data!)
          .single;
      return int.parse(text.split(' ').first);
    }

    setUp(() {
      repo.transactions = [
        for (var i = 0; i < 8; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(today.year, today.month, today.day, 12, 59 - i),
            note: 'Row $i',
          ),
      ];
    });

    Future<TestGesture> holdOn(WidgetTester tester, String row) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(row)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      return gesture;
    }

    testWidgets('long-press then drag down selects the rows passed over, and '
        'dragging back un-selects them', (tester) async {
      await pump(tester);
      final rowHeight = tester.getSize(find.text('Row 0')).height;
      expect(rowHeight, greaterThan(0));
      final step =
          tester.getCenter(find.text('Row 1')).dy -
          tester.getCenter(find.text('Row 0')).dy;

      final gesture = await holdOn(tester, 'Row 1');
      expect(selectedCount(tester), 1);

      await gesture.moveBy(Offset(0, step * 2));
      await tester.pump();
      expect(selectedCount(tester), 3);

      await gesture.moveBy(Offset(0, -step * 3));
      await tester.pump();
      expect(selectedCount(tester), 2);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 2);
    });

    testWidgets('starting the drag on an already-selected row deselects the '
        'rows passed over', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Select all (8)'));
      await tester.pumpAndSettle();
      expect(selectedCount(tester), 8);

      final step =
          tester.getCenter(find.text('Row 1')).dy -
          tester.getCenter(find.text('Row 0')).dy;
      final gesture = await holdOn(tester, 'Row 2');
      expect(selectedCount(tester), 7);
      await gesture.moveBy(Offset(0, step));
      await tester.pump();
      expect(selectedCount(tester), 6);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('drag-selecting downward from the top does not trigger '
        'pull-to-refresh', (tester) async {
      await pump(tester);
      final gesture = await holdOn(tester, 'Row 0');
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repo.syncNowCalls, 0);
      expect(find.textContaining(' selected'), findsOneWidget);
    });

    testWidgets('pulling down at the top while in selection mode does not '
        'trigger a refresh', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Row 1'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(repo.syncNowCalls, 0);
    });

    testWidgets('pulling down at the top outside selection mode still '
        'refreshes', (tester) async {
      await pump(tester);
      await tester.drag(find.text('Row 1'), const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(repo.syncNowCalls, 1);
    });

    testWidgets('a plain drag still scrolls and selects nothing', (
      tester,
    ) async {
      await pump(tester);
      await tester.drag(find.text('Row 1'), const Offset(0, -80));
      await tester.pumpAndSettle();
      expect(find.textContaining(' selected'), findsNothing);
    });

    testWidgets('holding the pointer near the bottom edge auto-scrolls and '
        'keeps extending the selection', (tester) async {
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.transactions = [
        for (var i = 0; i < 30; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(
              today.year,
              today.month,
              today.day,
              12,
              59 - (i % 59),
            ),
            note: 'Row $i',
          ),
      ];
      await pump(tester);

      final gesture = await holdOn(tester, 'Row 0');
      final before = selectedCount(tester);
      final bottom = tester.getBottomLeft(find.byType(ListView)).dy;
      await gesture.moveTo(Offset(400, bottom - 4));
      await tester.pump(const Duration(milliseconds: 1000));

      expect(selectedCount(tester), greaterThan(before + 3));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.position.pixels, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    });
  });

  group('mouse drag-scrolling (desktop)', () {
    testWidgets('dragging a mouse outside the checkbox column scrolls the '
        'list and selects nothing', (tester) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.transactions = [
        for (var i = 0; i < 30; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(2026, 1, 5, 12, 59 - i),
            note: 'Row $i',
          ),
      ];
      await pump(tester);

      final scrollable = Scrollable.of(tester.element(find.text('Row 0')));
      final gesture = await tester.startGesture(
        const Offset(600, 300),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, -150));
      await gesture.moveBy(const Offset(0, -150));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, greaterThan(100));
      expect(find.textContaining(' selected'), findsNothing);
    });

    testWidgets('dragging a mouse down the checkbox column selects without '
        'scrolling the list', (tester) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.transactions = [
        for (var i = 0; i < 30; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(2026, 1, 5, 12, 59 - i),
            note: 'Row $i',
          ),
      ];
      await pump(tester);

      final scrollable = Scrollable.of(tester.element(find.text('Row 0')));
      final start = tester.getCenter(find.byType(Checkbox).at(2));
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(0, 60));
      await gesture.moveBy(const Offset(0, 60));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(scrollable.position.pixels, 0);
      expect(find.textContaining(' selected'), findsOneWidget);
    });
  });

  group('shift-click range (desktop)', () {
    testWidgets('shift-clicking a row checkbox selects everything between '
        'it and the previously clicked row', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.transactions = [
        for (var i = 0; i < 5; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(2026, 1, 5, 12, 59 - i),
            note: 'Row $i',
          ),
      ];
      await pump(tester);

      await tester.tap(find.byType(Checkbox).at(2));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.byType(Checkbox).at(5));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(find.text('4 selected'), findsOneWidget);
    });

    testWidgets('a mouse press-and-drag down the checkbox column selects '
        'the rows passed over', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repo.transactions = [
        for (var i = 0; i < 5; i++)
          _incomeRow(
            id: 'tx$i',
            date: DateTime(2026, 1, 5, 12, 59 - i),
            note: 'Row $i',
          ),
      ];
      await pump(tester);

      final start = tester.getCenter(find.byType(Checkbox).at(2));
      final end = tester.getCenter(find.byType(Checkbox).at(4));
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(Offset(start.dx, (start.dy + end.dy) / 2));
      await tester.pump();
      await gesture.moveTo(end);
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.text('3 selected'), findsOneWidget);
    });
  });

  group('desktop table (≥900px)', () {
    Future<void> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
    }

    testWidgets(
      'shows a flat, date-column table instead of day-grouped tiles',
      (tester) async {
        repo.transactions = [
          _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
          _holderTransferRow(
            id: 'tx2',
            date: DateTime(2026, 1, 5),
            note: 'Between accounts',
          ),
        ];
        await pumpWide(tester);

        expect(find.text('Paycheck'), findsOneWidget);
        expect(find.text('Between accounts'), findsOneWidget);
        expect(find.byType(Checkbox), findsNWidgets(4));
        expect(find.text('DESCRIPTION'), findsOneWidget);
      },
    );

    testWidgets('checking a row checkbox enters selection mode', (
      tester,
    ) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
      ];
      await pumpWide(tester);

      expect(find.text('1 selected'), findsNothing);
      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('the column-header checkbox selects every row', (tester) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
        _incomeRow(id: 'tx2', date: DateTime(2026, 1, 4), note: 'Bonus'),
      ];
      await pumpWide(tester);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets(
      'has no "Select transactions" button — the table\'s checkboxes are '
      'already always visible, so it would be pure redundancy',
      (tester) async {
        repo.transactions = [
          _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
        ];
        await pumpWide(tester);

        expect(find.byIcon(Icons.checklist), findsNothing);
      },
    );

    testWidgets('tapping the row delete icon confirms then calls '
        'DomainRepository.deleteTransaction with just that row\'s id', (
      tester,
    ) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
      ];
      await pumpWide(tester);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(repo.singleDeleteCalls, equals(['tx1']));
    });

    testWidgets('a selected row that gets deleted is dropped from the '
        'selection (and selection mode ends)', (tester) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
        _incomeRow(id: 'tx2', date: DateTime(2026, 1, 4), note: 'Bonus'),
      ];
      final live = repo.liveTransactions = StreamController.broadcast();
      addTearDown(live.close);
      await pumpWide(tester);

      await tester.tap(find.byType(Checkbox).last);
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      live.add([repo.transactions.first]);
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsNothing);
      expect(find.textContaining('Bonus'), findsNothing);
    });

    testWidgets('tapping a row opens it for edit', (tester) async {
      repo.transactions = [
        _incomeRow(id: 'tx1', date: DateTime(2026, 1, 5), note: 'Paycheck'),
      ];
      repo.containers = [
        const ldb.Container(
          id: _bankId,
          name: 'Bank',
          containerType: 'holder',
          deleted: false,
        ),
        const ldb.Container(
          id: _budgetId,
          name: 'Groceries',
          containerType: 'budget',
          deleted: false,
        ),
      ];
      await pumpWide(tester);

      await tester.tap(find.text('Paycheck'));
      await tester.pumpAndSettle();

      expect(find.text('Edit transaction'), findsOneWidget);
    });
  });

  testWidgets('the reorder sheet scrolls instead of overflowing when the '
      'same-day cluster is taller than the screen', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 1, 5, 12);
    repo.transactions = [
      for (var i = 0; i < 30; i++)
        _incomeRow(id: 'tx$i', date: day, note: 'Entry $i'),
    ];
    await pump(tester);

    await tester.tap(find.byTooltip('Reorder 30 same-day entries').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final save = find.text('Save order');
    expect(save, findsOneWidget);
    expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(700));
  });

  group('future transactions (mobile)', () {
    DateTime day(int offset) {
      final n = DateTime.now();
      return DateTime(n.year, n.month, n.day + offset);
    }

    void seed({required int future, required int past}) {
      repo.transactions = [
        for (var i = 1; i <= future; i++)
          _incomeRow(id: 'f$i', date: day(i), note: 'Future $i'),
        _incomeRow(id: 'today', date: day(0), note: 'Today row'),
        for (var i = 1; i <= past; i++)
          _incomeRow(id: 'p$i', date: day(-i), note: 'Past $i'),
      ];
    }

    final marker = find.byKey(const ValueKey('nowMarker'));
    final button = find.byKey(const ValueKey('scrollToNow'));

    testWidgets('opens scrolled to the Now marker, so today is on screen '
        'and the button stays hidden', (tester) async {
      seed(future: 10, past: 15);
      await pump(tester);

      expect(marker, findsOneWidget);
      expect(find.text('Today row'), findsOneWidget);
      expect(find.text('Future 10'), findsNothing);
      expect(button, findsNothing);
    });

    testWidgets('scrolling the marker out of view up shows an up-arrow Now '
        'button, which scrolls back to it', (tester) async {
      seed(future: 10, past: 15);
      await pump(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(marker, findsNothing);
      expect(button, findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(marker, findsOneWidget);
      expect(button, findsNothing);
    });

    testWidgets('scrolling to the top (future side) shows a down-arrow Now '
        'button', (tester) async {
      seed(future: 10, past: 15);
      await pump(tester);

      await tester.fling(find.byType(ListView), const Offset(0, 3000), 5000);
      await tester.pumpAndSettle();
      expect(find.text('Future 10'), findsOneWidget);
      expect(button, findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(marker, findsOneWidget);
      expect(button, findsNothing);
    });

    testWidgets('the initial scroll to Now is animated, not a jump', (
      tester,
    ) async {
      seed(future: 10, past: 15);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [domainRepositoryProvider.overrideWithValue(repo)],
          child: const MaterialApp(
            scrollBehavior: AppScrollBehavior(),
            home: Scaffold(body: TransactionsScreen()),
          ),
        ),
      );
      ScrollPosition? position;
      for (var i = 0; i < 40 && (position?.pixels ?? 0) == 0; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final scrollables = find.byType(Scrollable);
        if (scrollables.evaluate().isNotEmpty) {
          position = tester.state<ScrollableState>(scrollables.first).position;
        }
      }
      expect(position!.pixels, greaterThan(0));
      final midway = position.pixels;

      await tester.pumpAndSettle();
      expect(position.pixels, greaterThan(midway));
      expect(marker, findsOneWidget);
    });

    testWidgets('with nothing in the future there is no marker, the list '
        'opens at the top, and the Now button scrolls back to the top', (
      tester,
    ) async {
      seed(future: 0, past: 15);
      await pump(tester);
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(marker, findsNothing);
      expect(position.pixels, 0);
      expect(button, findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();
      expect(marker, findsNothing);
      expect(position.pixels, greaterThan(0));
      expect(button, findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(button, findsNothing);
    });

    testWidgets('the Now button hides while selecting', (tester) async {
      seed(future: 10, past: 15);
      await pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(button, findsOneWidget);

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      expect(button, findsNothing);
    });

    testWidgets('the Future filter lists only future days, with no marker', (
      tester,
    ) async {
      seed(future: 3, past: 3);
      await pump(tester);

      await tester.tap(find.byIcon(Icons.tune));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Future'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Future 1'), findsOneWidget);
      expect(find.text('Today row'), findsNothing);
      expect(find.text('Past 1'), findsNothing);
      expect(marker, findsNothing);
    });
  });

  group('transfer groups', () {
    final day = DateTime(2026, 1, 5);

    setUp(() {
      repo.containers = [
        ...repo.containers,
        _budget('income', 'Income'),
        _budget('housing', 'Housing'),
        _budget('invest', 'Investments'),
        _budget('rent', 'Rent'),
        _budget('utils', 'Utilities'),
      ];
    });

    void twoTransfers() {
      repo.transactions = [
        _budgetTransferRow(
          id: 't1',
          from: 'income',
          to: 'housing',
          date: day,
          quantity: '30',
          note: 'Rent money',
        ),
        _budgetTransferRow(
          id: 't2',
          from: 'income',
          to: 'invest',
          date: day,
          quantity: '20',
          note: 'Invest money',
        ),
      ];
    }

    Future<void> pumpWide(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pump(tester);
    }

    testWidgets('mobile: collapses to one expandable row with the total and '
        'per-destination amounts; tapping expands, then collapses', (
      tester,
    ) async {
      twoTransfers();
      await pump(tester);

      expect(find.text('Income · 2 transfers'), findsOneWidget);
      expect(find.text('50.00 EUR'), findsOneWidget);
      expect(find.text('→ 30.00 EUR  Housing'), findsOneWidget);
      expect(find.text('→ 20.00 EUR  Investments'), findsOneWidget);
      expect(find.text('Income → Housing'), findsNothing);

      await tester.tap(find.text('Income · 2 transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Income → Housing'), findsOneWidget);
      expect(find.text('Income → Investments'), findsOneWidget);

      await tester.tap(find.text('Income · 2 transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Income → Housing'), findsNothing);
    });

    testWidgets('mobile: every destination is listed, however many', (
      tester,
    ) async {
      repo.containers = [
        ...repo.containers,
        for (var i = 0; i < 6; i++) _budget('d$i', 'Dest $i'),
      ];
      repo.transactions = [
        for (var i = 0; i < 6; i++)
          _budgetTransferRow(id: 't$i', from: 'income', to: 'd$i', date: day),
      ];
      await pump(tester);

      for (var i = 0; i < 6; i++) {
        expect(find.textContaining('Dest $i'), findsOneWidget);
      }
    });

    testWidgets('mobile: the group checkbox selects every transfer under it '
        '(tri-state when only some are selected)', (tester) async {
      twoTransfers();
      await pump(tester);

      await tester.tap(find.text('Income · 2 transfers'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();

      Checkbox groupBox() => tester.widget<Checkbox>(
        find
            .descendant(
              of: find.byType(ListTile),
              matching: find.byType(Checkbox),
            )
            .first,
      );
      expect(groupBox().value, isFalse);

      await tester.tap(find.byWidget(groupBox()));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(groupBox().value, isTrue);

      await tester.tap(find.text('Income → Housing'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      expect(groupBox().value, isNull);
    });

    testWidgets('mobile: a conflict on a hidden transfer still shows on the '
        'collapsed group', (tester) async {
      twoTransfers();
      repo.statuses = {'t2': RecordSyncStatus.conflicted};
      await pump(tester);

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('mobile: expansion survives a list rebuild and is dropped '
        'when the group goes away', (tester) async {
      twoTransfers();
      final live = StreamController<List<ldb.Transaction>>();
      addTearDown(live.close);
      repo.liveTransactions = live;
      await pump(tester);

      await tester.tap(find.text('Income · 2 transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Income → Housing'), findsOneWidget);

      live.add([...repo.transactions]);
      await tester.pumpAndSettle();
      expect(find.text('Income → Housing'), findsOneWidget);

      live.add([repo.transactions.first]);
      await tester.pumpAndSettle();
      expect(find.textContaining('transfers'), findsNothing);
      expect(find.text('Income → Housing'), findsOneWidget);

      live.add([...repo.transactions]);
      await tester.pumpAndSettle();
      expect(find.text('Income · 2 transfers'), findsOneWidget);
      expect(find.text('Income → Housing'), findsNothing);
    });

    testWidgets('mobile: a follow-up group nests under the destination that '
        'funds it', (tester) async {
      repo.transactions = [
        ...[
          _budgetTransferRow(
            id: 't1',
            from: 'income',
            to: 'housing',
            date: day,
            quantity: '100',
          ),
          _budgetTransferRow(
            id: 't2',
            from: 'income',
            to: 'invest',
            date: day,
            quantity: '50',
          ),
          _budgetTransferRow(
            id: 't3',
            from: 'housing',
            to: 'rent',
            date: day,
            quantity: '60',
          ),
          _budgetTransferRow(
            id: 't4',
            from: 'housing',
            to: 'utils',
            date: day,
            quantity: '40',
          ),
        ],
      ];
      await pump(tester);

      expect(find.text('Income · 4 transfers'), findsOneWidget);
      expect(find.text('150.00 EUR'), findsOneWidget);
      expect(find.text('Housing · 2 transfers'), findsNothing);

      await tester.tap(find.text('Income · 4 transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Housing · 2 transfers'), findsOneWidget);
      expect(find.text('100.00 EUR'), findsWidgets);

      await tester.tap(find.text('Housing · 2 transfers'));
      await tester.pumpAndSettle();
      expect(find.text('Housing → Rent'), findsOneWidget);
    });

    testWidgets('desktop: group header shows the total and destination '
        'amounts, expands to the original rows, and selects its leaves', (
      tester,
    ) async {
      twoTransfers();
      await pumpWide(tester);

      expect(find.text('2 transfers · Income'), findsOneWidget);
      expect(find.text('50.00 EUR'), findsOneWidget);
      expect(find.text('30.00 EUR'), findsOneWidget);
      expect(find.text('20.00 EUR'), findsOneWidget);
      expect(find.text('Rent money'), findsNothing);

      await tester.tap(find.text('2 transfers · Income'));
      await tester.pumpAndSettle();
      expect(find.text('Rent money'), findsOneWidget);
      expect(find.text('Invest money'), findsOneWidget);

      final groupBox = find.descendant(
        of: find.byKey(const ValueKey('group-header-income|t1')),
        matching: find.byType(Checkbox),
      );
      await tester.tap(groupBox);
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
    });

    testWidgets('desktop: a partly selected group shows an indeterminate '
        'checkbox', (tester) async {
      twoTransfers();
      await pumpWide(tester);
      await tester.tap(find.text('2 transfers · Income'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(3));
      await tester.pumpAndSettle();

      final groupBox = tester.widget<Checkbox>(
        find.descendant(
          of: find.byKey(const ValueKey('group-header-income|t1')),
          matching: find.byType(Checkbox),
        ),
      );
      expect(groupBox.value, isNull);
    });

    testWidgets('desktop: the flow button opens the Sankey in a dialog and '
        'does not expand the group', (tester) async {
      twoTransfers();
      await pumpWide(tester);

      await tester.tap(find.byTooltip('Show flow'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Income · 2 transfers'), findsOneWidget);
      expect(find.byType(TransferFlowChart), findsOneWidget);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Rent money'), findsNothing);
    });

    testWidgets('mobile: the flow button opens the Sankey as a page and does '
        'not expand the group', (tester) async {
      twoTransfers();
      await pump(tester);

      await tester.tap(find.byTooltip('Show flow'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(TransferFlowChart), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Income → Housing'), findsNothing);
    });

    testWidgets('mobile: the flow button is hidden in selection mode', (
      tester,
    ) async {
      twoTransfers();
      await pump(tester);
      expect(find.byTooltip('Show flow'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.checklist));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Show flow'), findsNothing);
    });

    testWidgets('mobile: a holder-transfer group has the flow button too', (
      tester,
    ) async {
      repo.transactions = [
        for (final (i, to) in ['holder-x', 'holder-y'].indexed)
          _holderTransferRow(id: 'h$i', to: to, date: day),
      ];
      await pump(tester);
      expect(find.byTooltip('Show flow'), findsOneWidget);
    });
  });
}

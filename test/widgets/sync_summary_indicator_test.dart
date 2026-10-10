import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/providers/auth_controller.dart';
import 'package:moopro/screens/attach_to_account_screen.dart';
import 'package:moopro/widgets/sync_summary_indicator.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    SyncSummary summary, {
    bool? serverAvailable = true,
    bool offlineVault = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncSummaryProvider.overrideWithValue(summary),
          serverAvailableProvider.overrideWith(
            (ref) => serverAvailable == null
                ? const Stream<bool>.empty()
                : Stream.value(serverAvailable),
          ),
          authControllerProvider.overrideWith((ref) {
            final controller = AuthController(
              ref,
              knownVaultsOverride: () async => [],
            );
            if (offlineVault) controller.state = const AuthOfflineReady();
            return controller;
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(appBar: null, body: SyncSummaryIndicator()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('all synced shows "All changes saved"', (tester) async {
    await pump(tester, const SyncSummary(pendingCount: 0, conflictedCount: 0));

    expect(find.text('All changes saved'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });

  testWidgets('pending changes shows the count', (tester) async {
    await pump(tester, const SyncSummary(pendingCount: 3, conflictedCount: 0));

    expect(find.text('3 pending'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
  });

  testWidgets('a conflict takes priority over pending and shows "Sync error"', (
    tester,
  ) async {
    await pump(tester, const SyncSummary(pendingCount: 2, conflictedCount: 1));

    expect(find.text('Sync error'), findsOneWidget);
    expect(find.text('2 pending'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('multiple conflicts show a count', (tester) async {
    await pump(tester, const SyncSummary(pendingCount: 0, conflictedCount: 2));

    expect(find.text('Sync error (2)'), findsOneWidget);
  });

  testWidgets('offline (and otherwise synced) shows "Offline"', (tester) async {
    await pump(
      tester,
      const SyncSummary(pendingCount: 0, conflictedCount: 0),
      serverAvailable: false,
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('All changes saved'), findsNothing);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('offline with pending changes shows "Offline", not the '
      'pending count', (tester) async {
    await pump(
      tester,
      const SyncSummary(pendingCount: 3, conflictedCount: 0),
      serverAvailable: false,
    );

    expect(find.text('Offline'), findsOneWidget);
    expect(find.text('3 pending'), findsNothing);
  });

  testWidgets('a conflict still wins over offline', (tester) async {
    await pump(
      tester,
      const SyncSummary(pendingCount: 0, conflictedCount: 1),
      serverAvailable: false,
    );

    expect(find.text('Sync error'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('a pending health check (still loading) does not flash '
      '"Offline" — falls through to the pending count', (tester) async {
    await pump(
      tester,
      const SyncSummary(pendingCount: 1, conflictedCount: 0),
      serverAvailable: null,
    );

    expect(find.text('1 pending'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
  });

  testWidgets('an offline vault with a reachable server shows "Log in to sync" '
      'instead of the normal summary', (tester) async {
    await pump(
      tester,
      const SyncSummary(pendingCount: 3, conflictedCount: 0),
      offlineVault: true,
    );

    expect(find.text('Log in to sync'), findsOneWidget);
    expect(find.text('3 pending'), findsNothing);

    await tester.tap(find.text('Log in to sync'));
    await tester.pumpAndSettle();

    expect(find.byType(AttachToAccountScreen), findsOneWidget);
  });

  testWidgets(
    'an offline vault with no server reachable falls back to the normal '
    '"Offline" summary, not the CTA',
    (tester) async {
      await pump(
        tester,
        const SyncSummary(pendingCount: 0, conflictedCount: 0),
        serverAvailable: false,
        offlineVault: true,
      );

      expect(find.text('Log in to sync'), findsNothing);
      expect(find.text('Offline'), findsOneWidget);
    },
  );
}

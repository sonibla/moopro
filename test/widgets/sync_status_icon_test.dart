import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/sync/sync_engine.dart';
import 'package:moopro/widgets/sync_status_icon.dart';

void main() {
  const recordId = 'rec1';

  Future<void> pump(
    WidgetTester tester,
    RecordSyncStatus status, {
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordSyncStatusesProvider.overrideWith(
            (ref) => Stream.value({recordId: status}),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SyncStatusIcon(recordId: recordId, onTap: onTap),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('synced renders the cloud-done icon and is not tappable', (
    tester,
  ) async {
    await pump(tester, RecordSyncStatus.synced);

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('pending renders the cloud-upload icon and is not tappable', (
    tester,
  ) async {
    await pump(tester, RecordSyncStatus.pending);

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('conflicted renders a distinct icon (not color-only) and invokes '
      'onTap when tapped', (tester) async {
    var tapped = false;
    await pump(tester, RecordSyncStatus.conflicted, onTap: () => tapped = true);

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.byType(InkWell));
    expect(tapped, isTrue);
  });

  testWidgets('conflicted with no onTap is not tappable', (tester) async {
    await pump(tester, RecordSyncStatus.conflicted);

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a record id missing from the status map defaults to synced', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordSyncStatusesProvider.overrideWith(
            (ref) => Stream.value(const {}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SyncStatusIcon(recordId: recordId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
  });
}

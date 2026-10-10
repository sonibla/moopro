import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/widgets/asset_picker.dart';

void main() {
  const eur = ldb.Asset(
    id: 'eur0000000000',
    kind: 'fiat',
    symbol: 'EUR',
    name: 'Euro',
    deleted: false,
  );
  const usd = ldb.Asset(
    id: 'usd0000000000',
    kind: 'fiat',
    symbol: 'USD',
    name: 'US Dollar',
    deleted: false,
  );
  const btc = ldb.Asset(
    id: 'btc0000000000',
    kind: 'crypto',
    symbol: 'BTC',
    name: 'Bitcoin',
    deleted: false,
  );
  const aapl = ldb.Asset(
    id: 'aapl000000000',
    kind: 'stock',
    symbol: 'AAPL',
    name: 'Apple Inc.',
    deleted: false,
  );
  final assets = [eur, usd, btc, aapl];

  Widget harness() => MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            await showAssetPicker(
              context: context,
              assets: assets,
              selectedId: eur.id,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  testWidgets('groups assets by kind with a section header each', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('FIAT CURRENCY (2)'), findsOneWidget);
    expect(find.text('STOCK (1)'), findsOneWidget);
    expect(find.text('CRYPTO (1)'), findsOneWidget);
    expect(find.text('EUR'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
    expect(find.text('BTC'), findsOneWidget);
    expect(find.text('AAPL'), findsOneWidget);
  });

  testWidgets('marks the currently selected asset with a checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final eurTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('EUR'), matching: find.byType(ListTile)),
    );
    expect(eurTile.trailing, isNotNull);

    final usdTile = tester.widget<ListTile>(
      find.ancestor(of: find.text('USD'), matching: find.byType(ListTile)),
    );
    expect(usdTile.trailing, isNull);
  });

  testWidgets(
    'searching flattens the list to symbol/name matches across kinds',
    (tester) async {
      await tester.pumpWidget(harness());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bit');
      await tester.pumpAndSettle();

      expect(find.text('BTC'), findsOneWidget);
      expect(find.text('EUR'), findsNothing);
      expect(find.text('FIAT CURRENCY'), findsNothing);
    },
  );

  testWidgets('tapping a row returns its id and closes the picker', (
    tester,
  ) async {
    late String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAssetPicker(
                  context: context,
                  assets: assets,
                  selectedId: eur.id,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('BTC'));
    await tester.pumpAndSettle();

    expect(result, btc.id);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('dismissing without a choice returns null', (tester) async {
    late String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showAssetPicker(
                  context: context,
                  assets: assets,
                  selectedId: eur.id,
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets(
    'opens as a dialog instead of a bottom sheet above the 900px breakpoint',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(harness());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );
}

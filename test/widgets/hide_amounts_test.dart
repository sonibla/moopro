import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/db/domain_cache_database.dart' as ldb;
import 'package:moopro/domain/domain_repository.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/amount_text.dart';
import 'package:moopro/widgets/hide_amounts_button.dart';

class _FakeRepo implements DomainRepository {
  final _controller = StreamController<ldb.Setting?>.broadcast();
  ldb.Setting? current;
  final List<String> writes = [];

  _FakeRepo([String? initial]) {
    if (initial != null) {
      current = ldb.Setting(
        id: SettingIds.hideAmounts,
        value: initial,
        deleted: false,
      );
    }
  }

  @override
  Stream<ldb.Setting?> watchSetting(String id) async* {
    yield current;
    yield* _controller.stream;
  }

  @override
  Future<void> setSetting(String id, String value) async {
    expect(id, SettingIds.hideAmounts);
    writes.add(value);
    current = ldb.Setting(id: id, value: value, deleted: false);
    _controller.add(current);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _eur = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
  displaySymbol: '€',
);

Finder _faIcon(FaIconData icon) => find.byWidgetPredicate(
  (w) => w is FaIcon && w.icon?.codePoint == icon.codePoint,
);

Widget _app(_FakeRepo repo, Widget child) => ProviderScope(
  overrides: [domainRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  group('hideAmountsProvider', () {
    Future<bool> read(String? stored) async {
      final container = ProviderContainer(
        overrides: [
          domainRepositoryProvider.overrideWithValue(_FakeRepo(stored)),
        ],
      );
      addTearDown(container.dispose);
      container.listen(hideAmountsProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      return container.read(hideAmountsProvider);
    }

    test('is false while unset', () async => expect(await read(null), isFalse));
    test("is true for '1'", () async => expect(await read('1'), isTrue));
    test("is false for '0'", () async => expect(await read('0'), isFalse));
  });

  group('formatAssetQuantity', () {
    test('shows the number by default', () {
      expect(formatAssetQuantity(Decimal.parse('12.5'), _eur), '12.50 €');
    });

    test('masks the number but keeps the glyph when hidden', () {
      expect(
        formatAssetQuantity(Decimal.parse('12.5'), _eur, hidden: true),
        '$kHiddenAmount €',
      );
    });
  });

  group('AmountText / TradeAmountText when hidden', () {
    testWidgets('mask the digits, keep the sign and the glyph', (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeRepo('1'),
          Column(
            children: [
              AmountText(
                quantity: Decimal.parse('12.5'),
                asset: _eur,
                sign: AmountSign.negative,
              ),
              AmountText(quantity: Decimal.parse('99'), asset: _eur),
            ],
          ),
        ),
      );
      await tester.pump();

      expect(find.text('−$kHiddenAmount €'), findsOneWidget);
      expect(find.text('$kHiddenAmount €'), findsOneWidget);
      expect(find.textContaining('12.50'), findsNothing);
      expect(find.textContaining('99'), findsNothing);
    });

    testWidgets('a trade masks both sides', (tester) async {
      await tester.pumpWidget(
        _app(
          _FakeRepo('1'),
          TradeAmountText(
            quantityOut: Decimal.parse('500'),
            assetOut: _eur,
            quantityIn: Decimal.parse('0.0071'),
            assetIn: const Asset(
              id: 'btc',
              kind: AssetKind.crypto,
              symbol: 'BTC',
              name: 'Bitcoin',
              displaySymbol: '₿',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('$kHiddenAmount € → $kHiddenAmount ₿'), findsOneWidget);
    });

    testWidgets('show the number again when the setting is off', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          _FakeRepo('0'),
          AmountText(quantity: Decimal.parse('12.5'), asset: _eur),
        ),
      );
      await tester.pump();

      expect(find.text('12.50 €'), findsOneWidget);
    });
  });

  group('HideAmountsButton', () {
    testWidgets('shows the eye + "Hide amounts" while amounts are shown, and '
        'tapping hides them', (tester) async {
      final repo = _FakeRepo();
      await tester.pumpWidget(_app(repo, const HideAmountsButton()));
      await tester.pump();

      expect(find.byTooltip('Hide amounts'), findsOneWidget);
      expect(_faIcon(FontAwesomeIcons.eye), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(repo.writes, ['1']);
      expect(find.byTooltip('Show amounts'), findsOneWidget);
      expect(_faIcon(FontAwesomeIcons.eyeSlash), findsOneWidget);
    });

    testWidgets('tapping it while hidden shows amounts again', (tester) async {
      final repo = _FakeRepo('1');
      await tester.pumpWidget(_app(repo, const HideAmountsButton()));
      await tester.pump();

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(repo.writes, ['0']);
      expect(find.byTooltip('Hide amounts'), findsOneWidget);
    });
  });
}

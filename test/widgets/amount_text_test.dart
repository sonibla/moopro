import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transaction_kind_style.dart';
import 'package:moopro/widgets/amount_text.dart';

const _eur = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
);
const _eurWithGlyph = Asset(
  id: 'eur',
  kind: AssetKind.fiat,
  symbol: 'EUR',
  name: 'Euro',
  displaySymbol: '€',
);
const _btc = Asset(
  id: 'btc',
  kind: AssetKind.crypto,
  symbol: 'BTC',
  name: 'Bitcoin',
  displaySymbol: '₿',
);

void main() {
  testWidgets('caps to a single line so a long asset symbol/name never '
      'wraps the row it sits in (fixed-height row layouts rely on this)', (
    tester,
  ) async {
    const asset = Asset(
      id: 'a1',
      kind: AssetKind.realEstateBond,
      symbol:
          'A Very Long Real Estate Bond Project Name That Would Otherwise Wrap',
      name:
          'A Very Long Real Estate Bond Project Name That Would Otherwise Wrap',
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 80,
              child: AmountText(
                quantity: Decimal.parse('1000'),
                asset: asset,
                sign: AmountSign.neutral,
              ),
            ),
          ),
        ),
      ),
    );

    final text = tester.widget<Text>(find.byType(Text));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(text.softWrap, isFalse);
  });

  group('assetGlyph/formatAssetQuantity', () {
    test('prefers displaySymbol (the glyph) when set', () {
      expect(assetGlyph(_eurWithGlyph), equals('€'));
    });

    test('falls back to the plain symbol when no glyph is set', () {
      expect(assetGlyph(_eur), equals('EUR'));
    });

    test('crypto formats to 8 decimals, everything else to 2', () {
      expect(
        formatAssetQuantity(Decimal.parse('0.0071'), _btc),
        equals('0.00710000 ₿'),
      );
      expect(
        formatAssetQuantity(Decimal.parse('500'), _eurWithGlyph),
        equals('500.00 €'),
      );
    });
  });

  group('AmountText', () {
    testWidgets(
      'renders the asset glyph instead of its symbol when one is set',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: AmountText(
                  quantity: Decimal.parse('500'),
                  asset: _eurWithGlyph,
                  sign: AmountSign.neutral,
                ),
              ),
            ),
          ),
        );
        expect(find.textContaining('€'), findsOneWidget);
        expect(find.textContaining('EUR'), findsNothing);
      },
    );
  });

  group('TradeAmountText', () {
    testWidgets('renders "give → get", each side using its own asset\'s '
        'glyph and decimal precision', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TradeAmountText(
                quantityOut: Decimal.parse('500'),
                assetOut: _eurWithGlyph,
                quantityIn: Decimal.parse('0.0071'),
                assetIn: _btc,
              ),
            ),
          ),
        ),
      );
      expect(find.text('500.00 € → 0.00710000 ₿'), findsOneWidget);
    });

    testWidgets('falls back to the plain symbol for a side with no glyph set', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TradeAmountText(
                quantityOut: Decimal.parse('500'),
                assetOut: _eur,
                quantityIn: Decimal.parse('0.0071'),
                assetIn: _btc,
              ),
            ),
          ),
        ),
      );
      expect(find.text('500.00 EUR → 0.00710000 ₿'), findsOneWidget);
    });

    testWidgets('renders in the trade kind\'s color, not a neutral/ink color', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return TradeAmountText(
                    quantityOut: Decimal.parse('500'),
                    assetOut: _eurWithGlyph,
                    quantityIn: Decimal.parse('0.0071'),
                    assetIn: _btc,
                  );
                },
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      final brightness = Theme.of(tester.element(find.byType(Text))).brightness;
      expect(
        text.style?.color,
        equals(TransactionKindStyle.colorOf(TransactionKind.trade, brightness)),
      );
    });

    testWidgets('allows up to 2 lines by default so a long give/get pair '
        'wraps instead of clipping', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TradeAmountText(
                quantityOut: Decimal.parse('500'),
                assetOut: _eurWithGlyph,
                quantityIn: Decimal.parse('0.0071'),
                assetIn: _btc,
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
    });
  });
}

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models.dart';
import '../domain/transaction_kind_style.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

enum AmountSign { positive, negative, neutral }

int assetDecimals(Asset asset) => asset.kind == AssetKind.crypto ? 8 : 2;

String assetGlyph(Asset asset) => asset.displaySymbol ?? asset.symbol;

const kHiddenAmount = '••••';

String formatQuantityNumber(Decimal quantity, Asset asset, bool hidden) =>
    hidden ? kHiddenAmount : quantity.toStringAsFixed(assetDecimals(asset));

String formatAssetQuantity(
  Decimal quantity,
  Asset asset, {
  bool hidden = false,
}) => '${formatQuantityNumber(quantity, asset, hidden)} ${assetGlyph(asset)}';

class AmountText extends ConsumerWidget {
  final Decimal quantity;
  final Asset asset;
  final AmountSign sign;
  final TextStyle? style;

  const AmountText({
    super.key,
    required this.quantity,
    required this.asset,
    this.sign = AmountSign.neutral,
    this.style,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.titleMedium;

    final hidden = ref.watch(hideAmountsProvider);
    String number(Decimal q) => formatQuantityNumber(q, asset, hidden);

    String formatted;
    Color? color;
    switch (sign) {
      case AmountSign.positive:
        formatted = '+${number(quantity.abs())}';
        color = AppTheme.positiveAmountColor(theme.brightness);
        break;
      case AmountSign.negative:
        formatted = '−${number(quantity.abs())}';
        color = AppTheme.negativeAmountColor(theme.brightness);
        break;
      case AmountSign.neutral:
        formatted = number(quantity);
        color = baseStyle?.color;
        break;
    }

    return Text(
      '$formatted ${assetGlyph(asset)}',
      style: AppTheme.amountTextStyle(baseStyle).copyWith(color: color),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      softWrap: false,
    );
  }
}

class TradeAmountText extends ConsumerWidget {
  final Decimal quantityOut;
  final Asset assetOut;
  final Decimal quantityIn;
  final Asset assetIn;
  final TextStyle? style;
  final int maxLines;
  final TextAlign? textAlign;

  const TradeAmountText({
    super.key,
    required this.quantityOut,
    required this.assetOut,
    required this.quantityIn,
    required this.assetIn,
    this.style,
    this.maxLines = 2,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.titleMedium;
    final hidden = ref.watch(hideAmountsProvider);
    final color = TransactionKindStyle.colorOf(
      TransactionKind.trade,
      theme.brightness,
    );

    return Text(
      '${formatAssetQuantity(quantityOut, assetOut, hidden: hidden)} → ${formatAssetQuantity(quantityIn, assetIn, hidden: hidden)}',
      style: AppTheme.amountTextStyle(baseStyle).copyWith(color: color),
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}

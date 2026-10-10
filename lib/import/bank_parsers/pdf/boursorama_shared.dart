import 'package:decimal/decimal.dart';

import 'fortuneo_shared.dart' show resolveSubsetSumCents;

Decimal parseAmountDotThousands(String raw) =>
    Decimal.parse(raw.replaceAll('.', '').replaceAll(',', '.'));

Decimal parseAmountSpaceThousands(String raw) => Decimal.parse(
  raw.replaceAll(RegExp('[ \u00A0\u202F.]'), '').replaceAll(',', '.'),
);

const amountSpaceThousandsToken = '\\d{1,3}(?:[ \u00A0\u202F.]\\d{3})*,\\d{2}';

const flexibleNumberToken = '\\d{1,3}(?:[ \u00A0\u202F.]\\d{3})*(?:,\\d+)?';

Set<int>? resolveAmbiguousDirectionsByBalance({
  required List<Decimal> ambiguousAmounts,
  required Decimal netTargetFromAmbiguous,
}) {
  if (ambiguousAmounts.isEmpty) return {};

  final cents = Decimal.fromInt(100);
  final totalCents = ambiguousAmounts.fold(
    BigInt.zero,
    (sum, a) => sum + (a * cents).toBigInt(),
  );
  final targetCents = (netTargetFromAmbiguous * cents).toBigInt();
  final creditTargetCentsX2 = targetCents + totalCents;
  if (creditTargetCentsX2.isOdd) return null;
  final creditTargetCents = creditTargetCentsX2 ~/ BigInt.two;
  if (creditTargetCents < BigInt.zero || creditTargetCents > totalCents) {
    return null;
  }

  final creditTargetDecimal = Decimal.fromBigInt(creditTargetCents).shift(-2);
  final resolved = resolveSubsetSumCents(ambiguousAmounts, creditTargetDecimal);
  if (resolved == null) return null;
  return {
    for (var i = 0; i < resolved.length; i++)
      if (resolved[i]) i,
  };
}

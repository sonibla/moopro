import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/holder_budget_consistency.dart';
import 'package:moopro/providers/app_providers.dart';
import 'package:moopro/widgets/consistency_warning_indicator.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    AsyncValue<HolderBudgetConsistency?> value,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          holderBudgetConsistencyProvider.overrideWith((ref) {
            return value.when(
              data: (d) => Future.value(d),
              loading: () => Completer<HolderBudgetConsistency?>().future,
              error: (e, st) => Future<HolderBudgetConsistency?>.error(e, st),
            );
          }),
          assetsStreamProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MaterialApp(
          home: Scaffold(appBar: null, body: ConsistencyWarningIndicator()),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('still loading renders nothing', (tester) async {
    await pump(tester, const AsyncLoading());

    expect(find.text('Out of sync'), findsNothing);
    expect(find.byType(SizedBox), findsOneWidget);
  });

  testWidgets('matching balances render nothing', (tester) async {
    await pump(
      tester,
      AsyncData(
        HolderBudgetConsistency(
          holderBalances: {'eur': Decimal.parse('1000')},
          budgetBalances: {'eur': Decimal.parse('1000')},
          mismatchesByAsset: const {},
        ),
      ),
    );

    expect(find.text('Out of sync'), findsNothing);
  });

  testWidgets('a per-asset mismatch shows the "Out of sync" warning', (
    tester,
  ) async {
    await pump(
      tester,
      AsyncData(
        HolderBudgetConsistency(
          holderBalances: {
            'eur': Decimal.parse('500'),
            'btc': Decimal.parse('5'),
          },
          budgetBalances: {'eur': Decimal.parse('1000')},
          mismatchesByAsset: {
            'eur': Decimal.parse('-500'),
            'btc': Decimal.parse('5'),
          },
        ),
      ),
    );

    expect(find.text('Out of sync'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
  });
}

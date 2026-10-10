import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/widgets/transaction_selection_bar.dart';

Widget _bar({
  int selected = 0,
  int total = 5,
  VoidCallback? onSelectAll,
  VoidCallback? onClose,
  VoidCallback? onMassEdit,
  VoidCallback? onStatistics,
}) => MaterialApp(
  home: Scaffold(
    appBar: TransactionSelectionBar(
      selectedCount: selected,
      totalCount: total,
      onSelectAll: onSelectAll ?? () {},
      onClose: onClose ?? () {},
      onCopy: () {},
      onMassEdit: onMassEdit ?? () {},
      onStatistics: onStatistics ?? () {},
      onDelete: () {},
    ),
  ),
);

Future<void> _setSize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

IconData _iconFor(String tip) => switch (tip) {
  'Statistics' => Icons.bar_chart,
  'Mass edit' => Icons.sell_outlined,
  'Copy to date' => Icons.content_copy,
  _ => Icons.delete_outline,
};

void main() {
  testWidgets('shows "Select all (N)" until everything is selected, then '
      '"Deselect all"', (tester) async {
    await _setSize(tester, const Size(1200, 800));
    await tester.pumpWidget(_bar(selected: 2, total: 5));
    expect(find.text('Select all (5)'), findsOneWidget);

    await tester.pumpWidget(_bar(selected: 5, total: 5));
    expect(find.text('Deselect all'), findsOneWidget);
  });

  testWidgets('Select all is disabled when the list is empty; Copy/Delete '
      'are disabled with nothing selected', (tester) async {
    await _setSize(tester, const Size(1200, 800));
    await tester.pumpWidget(_bar(selected: 0, total: 0));
    TextButton button(String label) =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, label));
    expect(button('Select all (0)').onPressed, isNull);
    expect(button('Delete').onPressed, isNull);
    expect(button('Copy to date').onPressed, isNull);
    expect(button('Mass edit').onPressed, isNull);
    expect(button('Statistics').onPressed, isNull);
  });

  testWidgets('tapping Select all and the close icon call their callbacks', (
    tester,
  ) async {
    await _setSize(tester, const Size(1200, 800));
    var selectAll = 0, close = 0;
    await tester.pumpWidget(
      _bar(onSelectAll: () => selectAll++, onClose: () => close++),
    );
    await tester.tap(find.text('Select all (5)'));
    await tester.tap(find.byTooltip('Cancel selection'));
    expect([selectAll, close], [1, 1]);
  });

  testWidgets('tapping Mass edit calls its callback', (tester) async {
    await _setSize(tester, const Size(1200, 800));
    var calls = 0;
    await tester.pumpWidget(_bar(selected: 2, onMassEdit: () => calls++));
    await tester.tap(find.text('Mass edit'));
    expect(calls, 1);
  });

  testWidgets('wide layout shows icon + text, and Statistics calls back', (
    tester,
  ) async {
    await _setSize(tester, const Size(1200, 800));
    var calls = 0;
    await tester.pumpWidget(_bar(selected: 2, onStatistics: () => calls++));
    expect(find.byIcon(Icons.bar_chart), findsOneWidget);
    await tester.tap(find.text('Statistics'));
    expect(calls, 1);
  });

  group('on a 360px-wide phone', () {
    Future<void> narrow(WidgetTester tester, Widget bar) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(bar);
    }

    testWidgets('uses icon actions and does not overflow, even with a '
        '4-digit count', (tester) async {
      await narrow(tester, _bar(selected: 1234, total: 5000));
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Select all (5000)'), findsOneWidget);
      expect(find.byTooltip('Statistics'), findsOneWidget);
      expect(find.byTooltip('Mass edit'), findsOneWidget);
      expect(find.byTooltip('Copy to date'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsOneWidget);
    });

    testWidgets('keeps every action visible, dimmed, with nothing selected', (
      tester,
    ) async {
      await narrow(tester, _bar(selected: 0, total: 5));
      for (final tip in ['Statistics', 'Mass edit', 'Copy to date', 'Delete']) {
        final button = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, _iconFor(tip)),
        );
        expect(button.onPressed, isNull, reason: tip);
        final color = button.style!.foregroundColor!.resolve({
          WidgetState.disabled,
        })!;
        expect(color.a, greaterThan(0.3), reason: tip);
        expect(color.computeLuminance(), greaterThan(0.5), reason: tip);
      }
    });

    testWidgets('the select-all icon swaps to Deselect all and calls back', (
      tester,
    ) async {
      var calls = 0;
      await narrow(
        tester,
        _bar(selected: 5, total: 5, onSelectAll: () => calls++),
      );
      await tester.tap(find.byTooltip('Deselect all'));
      expect(calls, 1);
    });
  });
}

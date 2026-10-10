import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/widgets/tag_pill_row.dart';

void main() {
  testWidgets('renders a Chip per tag, vertically centered within its lane', (
    tester,
  ) async {
    const laneHeight = 38.0;
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: TagPillRow(
              tags: ['Japan trip', 'Reimbursable'],
              height: laneHeight,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.widgetWithText(Chip, 'Japan trip'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Reimbursable'), findsOneWidget);

    final laneRect = tester.getRect(find.byType(TagPillRow));
    final chipRect = tester.getRect(find.widgetWithText(Chip, 'Japan trip'));

    expect(laneRect.height, laneHeight);
    expect(chipRect.height, lessThan(laneHeight));
    final topGap = chipRect.top - laneRect.top;
    final bottomGap = laneRect.bottom - chipRect.bottom;
    expect((topGap - bottomGap).abs(), lessThan(1.0));
  });

  testWidgets(
    'renders flush against the lane\'s left edge even when the lane is '
    'much wider than the tag content — the regression this fixes: a plain '
    '`Center` centers both axes, so a lane as wide as the whole '
    'description/title column above it left a large blank gap before the '
    'first tag instead of starting directly under that text',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: TagPillRow(tags: ['Japan trip'], height: 32),
            ),
          ),
        ),
      );
      await tester.pump();

      final laneRect = tester.getRect(find.byType(TagPillRow));
      final chipRect = tester.getRect(find.widgetWithText(Chip, 'Japan trip'));

      expect(laneRect.width, 400);
      expect(chipRect.left - laneRect.left, lessThan(1.0));
    },
  );

  testWidgets(
    'is horizontally scrollable when tags overflow the available width',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 100,
              child: TagPillRow(
                tags: List.generate(10, (i) => 'A fairly long tag label $i'),
                height: 38,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('A fairly long tag label 0'), findsOneWidget);
    },
  );

  testWidgets('shows tags alphabetically (case-insensitive)', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TagPillRow(tags: ['zebra', 'Apple', 'mango'], height: 32),
        ),
      ),
    );

    final xs = [
      for (final t in ['Apple', 'mango', 'zebra'])
        tester.getTopLeft(find.widgetWithText(Chip, t)).dx,
    ];
    expect(xs, [...xs]..sort());
  });
}

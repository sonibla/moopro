import 'package:decimal/decimal.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/transfer_flow.dart';
import 'package:moopro/widgets/transfer_flow_chart.dart';

final _eur = Asset.fromJson('eur', {
  'kind': 'fiat',
  'symbol': 'EUR',
  'name': 'Euro',
});

FlowNode _n(String id, int layer, String value) =>
    FlowNode(id: id, name: id, layer: layer, value: Decimal.parse(value));

FlowLink _l(String from, String to, String value, {bool back = false}) =>
    FlowLink(from: from, to: to, value: Decimal.parse(value), isBack: back);

Future<void> _pump(WidgetTester tester, TransferFlow flow, {double w = 360}) =>
    tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: w,
                child: TransferFlowChart(
                  flow: flow,
                  colorOf: (_) => Colors.teal,
                ),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('paints a multi-column flow at phone width without errors', (
    tester,
  ) async {
    await _pump(
      tester,
      TransferFlow(
        asset: _eur,
        nodes: [
          _n('inc', 0, '100'),
          _n('a', 1, '60'),
          _n('b', 1, '40'),
          _n('c', 2, '60'),
        ],
        links: [_l('inc', 'a', '60'), _l('inc', 'b', '40'), _l('a', 'c', '60')],
      ),
    );
    expect(find.byType(TransferFlowChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paints back links and tiny nodes without errors', (
    tester,
  ) async {
    await _pump(
      tester,
      TransferFlow(
        asset: _eur,
        nodes: [_n('a', 0, '1000'), _n('b', 1, '1000'), _n('c', 1, '0.01')],
        links: [
          _l('a', 'b', '1000'),
          _l('a', 'c', '0.01'),
          _l('b', 'a', '5', back: true),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('grows taller with the busiest column', (tester) async {
    final small = TransferFlow(
      asset: _eur,
      nodes: [_n('a', 0, '1'), _n('b', 1, '1')],
      links: [_l('a', 'b', '1')],
    );
    final big = TransferFlow(
      asset: _eur,
      nodes: [_n('a', 0, '10'), for (var i = 0; i < 12; i++) _n('d$i', 1, '1')],
      links: [for (var i = 0; i < 12; i++) _l('a', 'd$i', '1')],
    );
    expect(
      TransferFlowChart.heightFor(big),
      greaterThan(TransferFlowChart.heightFor(small)),
    );
  });

  testWidgets('hovering a node shows its name and amount, even a tiny one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pump(
      tester,
      TransferFlow(
        asset: _eur,
        nodes: [_n('Income', 0, '1000'), _n('Gifts', 1, '2')],
        links: [_l('Income', 'Gifts', '2')],
      ),
      w: 640,
    );

    final tooltips = find.byType(Tooltip);
    expect(tooltips, findsNWidgets(2));
    final gifts = tester.getCenter(tooltips.last);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(gifts);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Gifts\n2.00 EUR'), findsOneWidget);
  });
}

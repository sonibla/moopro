import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/widgets/bank_icons.dart';
import 'package:moopro/widgets/container_icon.dart';

void main() {
  testWidgets('every bundled bank icon renders without errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              for (final id in bankIconRegistry.keys)
                ContainerIcon('bank:$id', size: 96, color: Colors.black),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

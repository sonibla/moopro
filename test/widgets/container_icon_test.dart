import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:moopro/widgets/container_icon.dart';
import 'package:moopro/widgets/container_icon_picker.dart';
import 'package:moopro/widgets/fa_icon_registry.g.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('ContainerIconKey.parse', () {
    test('null, malformed and unknown keys resolve to nothing', () {
      expect(ContainerIconKey.parse(null), isNull);
      expect(ContainerIconKey.parse(''), isNull);
      expect(ContainerIconKey.parse('solidHouse'), isNull);
      expect(ContainerIconKey.parse('fa:doesNotExist'), isNull);
      expect(ContainerIconKey.parse('bank:doesNotExist'), isNull);
      expect(ContainerIconKey.parse('future:thing'), isNull);
    });

    test('a Font Awesome key resolves', () {
      expect(ContainerIconKey.parse('fa:solidHouse'), isA<FontAwesomeKey>());
    });

    test('registry is populated', () {
      expect(faIconRegistry.length, greaterThan(1000));
    });
  });

  group('ContainerIcon', () {
    testWidgets('renders a Font Awesome icon at the given size and colour', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ContainerIcon('fa:solidHouse', size: 18, color: Colors.red),
        ),
      );
      final icon = tester.widget<FaIcon>(find.byType(FaIcon));
      expect(icon.size, 18);
      expect(icon.color, Colors.red);
    });

    testWidgets('defaults its size to the ambient text size', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const DefaultTextStyle(
            style: TextStyle(fontSize: 33),
            child: ContainerIcon('fa:solidHouse'),
          ),
        ),
      );
      expect(tester.widget<FaIcon>(find.byType(FaIcon)).size, 33);
    });

    testWidgets('null and unresolvable keys render nothing', (tester) async {
      for (final key in [null, 'fa:nope', 'bank:nope', 'x']) {
        await tester.pumpWidget(_wrap(ContainerIcon(key)));
        expect(find.byType(FaIcon), findsNothing);
        expect(tester.getSize(find.byType(ContainerIcon)), Size.zero);
      }
    });
  });

  group('ContainerName', () {
    testWidgets('without an icon is just the text', (tester) async {
      await tester.pumpWidget(_wrap(const ContainerName('Bank')));
      expect(find.text('Bank'), findsOneWidget);
      expect(find.byType(FaIcon), findsNothing);
    });

    testWidgets('with an icon shows icon and name', (tester) async {
      await tester.pumpWidget(
        _wrap(const ContainerName('Bank', icon: 'fa:solidHouse')),
      );
      expect(find.textContaining('Bank'), findsOneWidget);
      expect(find.byType(FaIcon), findsOneWidget);
    });
  });

  group('showContainerIconPicker', () {
    Future<ContainerIconPick?> open(
      WidgetTester tester, {
      String? selected,
      Future<void> Function()? interact,
    }) async {
      ContainerIconPick? result;
      var done = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showContainerIconPicker(
                    context,
                    selected: selected,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await interact?.call();
      await tester.pumpAndSettle();
      return done ? result : null;
    }

    testWidgets('searching filters by name/keywords; selecting returns key', (
      tester,
    ) async {
      final result = await open(
        tester,
        interact: () async {
          await tester.enterText(find.byType(TextField), 'real estate');
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Solid House').first);
        },
      );
      expect(result, isNotNull);
      expect(result!.key, 'fa:solidHouse');
    });

    testWidgets('shows an empty state when nothing matches', (tester) async {
      await open(
        tester,
        interact: () async {
          await tester.enterText(find.byType(TextField), 'zzzzqqqq');
          await tester.pumpAndSettle();
          expect(find.text('No icons match'), findsOneWidget);
        },
      );
    });

    testWidgets('"No icon" returns a pick with a null key', (tester) async {
      final result = await open(
        tester,
        selected: 'fa:solidHouse',
        interact: () async => tester.tap(find.text('No icon')),
      );
      expect(result, isNotNull);
      expect(result!.key, isNull);
    });

    testWidgets('dismissing returns null (leave unchanged)', (tester) async {
      final result = await open(
        tester,
        interact: () async => tester.tap(find.byTooltip('Close')),
      );
      expect(result, isNull);
    });
  });
}

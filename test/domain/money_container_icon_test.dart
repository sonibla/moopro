import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';

void main() {
  const base = MoneyContainer(
    id: 'c1',
    name: 'Bank',
    containerType: ContainerType.holder,
  );

  test('toJson omits icon when null, includes it when set', () {
    expect(base.toJson().containsKey('icon'), isFalse);
    expect(base.copyWith(icon: () => 'bank:ing').toJson()['icon'], 'bank:ing');
  });

  test('fromJson reads icon; a legacy record without it decodes to null', () {
    final withIcon = MoneyContainer.fromJson('c1', {
      'name': 'Bank',
      'containerType': 'holder',
      'parentId': null,
      'icon': 'fa:solidHouse',
    });
    expect(withIcon.icon, 'fa:solidHouse');

    final legacy = MoneyContainer.fromJson('c1', {
      'name': 'Bank',
      'containerType': 'holder',
      'parentId': null,
    });
    expect(legacy.icon, isNull);
  });

  test(
    'copyWith leaves icon/parentId unchanged when omitted, clears on null',
    () {
      final c = base.copyWith(icon: () => 'bank:ing', parentId: () => 'p');
      expect(c.copyWith(name: 'X').icon, 'bank:ing');
      expect(c.copyWith(name: 'X').parentId, 'p');
      expect(c.copyWith(icon: () => null).icon, isNull);
      expect(c.copyWith(parentId: () => null).parentId, isNull);
    },
  );
}

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moopro/domain/models.dart';
import 'package:moopro/domain/recurring_projection.dart';
import 'package:moopro/domain/calendar_date.dart';

RecurringTransactionTemplate _template({
  required String id,
  required RecurrenceRule rule,
  bool active = true,
}) {
  final quantity = Decimal.parse('100');
  return RecurringTransactionTemplate(
    id: id,
    kind: TransactionKind.expense,
    legOut: RecurringLeg(
      containerId: 'holder',
      assetId: 'eur',
      quantity: quantity,
    ),
    legIn: RecurringLeg(
      containerId: externalHolderContainerId,
      assetId: 'eur',
      quantity: quantity,
    ),
    budgetLegOut: RecurringLeg(
      containerId: 'budget',
      assetId: 'eur',
      quantity: quantity,
    ),
    budgetLegIn: RecurringLeg(
      containerId: externalBudgetContainerId,
      assetId: 'eur',
      quantity: quantity,
    ),
    rule: rule,
    active: active,
  );
}

void main() {
  test('projects every occurrence in (from, to] across templates, sorted by '
      'date', () {
    final monthly = _template(
      id: 'monthly',
      rule: RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      ),
    );
    final quarterly = _template(
      id: 'quarterly',
      rule: RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 3,
      ),
    );

    final projected = projectOccurrences(
      [monthly, quarterly],
      from: CalendarDate(2026, 1, 15),
      to: CalendarDate(2026, 4, 30),
    );

    final pairs = projected.map((p) => (p.template.id, p.date)).toList();
    expect(
      pairs.sublist(0, 2),
      equals([
        ('monthly', CalendarDate(2026, 2, 1)),
        ('monthly', CalendarDate(2026, 3, 1)),
      ]),
    );
    expect(pairs.every((p) => p.$2.isBefore(CalendarDate(2026, 4, 2))), isTrue);
    expect(
      pairs.sublist(2).toSet(),
      equals({
        ('quarterly', CalendarDate(2026, 4, 1)),
        ('monthly', CalendarDate(2026, 4, 1)),
      }),
    );
  });

  test('skips paused (active: false) templates', () {
    final paused = _template(
      id: 'paused',
      active: false,
      rule: RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      ),
    );

    final projected = projectOccurrences(
      [paused],
      from: CalendarDate(2026, 1, 1),
      to: CalendarDate(2026, 12, 31),
    );

    expect(projected, isEmpty);
  });

  test('never mutates the templates it projects from', () {
    final template = _template(
      id: 'monthly',
      rule: RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      ),
    );

    projectOccurrences(
      [template],
      from: CalendarDate(2026, 1, 1),
      to: CalendarDate(2026, 6, 1),
    );

    expect(template.lastGeneratedOccurrenceDate, isNull);
  });

  test('empty range (from == to, nothing strictly after from) yields '
      'nothing', () {
    final template = _template(
      id: 'monthly',
      rule: RecurrenceRule(
        startDate: CalendarDate(2026, 1, 1),
        unit: RecurrenceUnit.month,
        interval: 1,
      ),
    );

    final projected = projectOccurrences(
      [template],
      from: CalendarDate(2026, 1, 1),
      to: CalendarDate(2026, 1, 1),
    );

    expect(projected, isEmpty);
  });
}

import 'calendar_date.dart';
import 'models.dart';
import 'recurrence_rule.dart';

class ProjectedOccurrence {
  final RecurringTransactionTemplate template;
  final CalendarDate date;

  const ProjectedOccurrence({required this.template, required this.date});
}

List<ProjectedOccurrence> projectOccurrences(
  List<RecurringTransactionTemplate> templates, {
  required CalendarDate from,
  required CalendarDate to,
}) {
  final result = <ProjectedOccurrence>[];
  for (final template in templates) {
    if (!template.active) continue;
    for (final date in occurrencesBetween(
      template.rule,
      after: from,
      upTo: to,
    )) {
      result.add(ProjectedOccurrence(template: template, date: date));
    }
  }
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

import 'calendar_date.dart';

class DateTick {
  final CalendarDate date;
  final String label;
  const DateTick(this.date, this.label);
}

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

List<DateTick> dateTicks(
  CalendarDate first,
  CalendarDate last, {
  required int maxTicks,
}) {
  if (maxTicks < 1 || last.isBefore(first)) return const [];

  final weekly = <CalendarDate>[];
  var d = first.addDays((8 - first.weekday) % 7);
  for (; !d.isAfter(last); d = d.addDays(7)) {
    weekly.add(d);
  }
  if (weekly.length <= maxTicks) {
    return [
      for (final t in weekly)
        DateTick(t, '${t.day} ${_monthNames[t.month - 1]}'),
    ];
  }

  for (final step in const [1, 2, 3, 6, 12, 24, 60, 120]) {
    final months = _monthStarts(first, last, step);
    if (months.length <= maxTicks || step == 120) {
      return [
        for (var i = 0; i < months.length; i++)
          DateTick(
            months[i],
            i == 0 || months[i].month == 1
                ? '${_monthNames[months[i].month - 1]} ${months[i].year}'
                : _monthNames[months[i].month - 1],
          ),
      ];
    }
  }
  return const [];
}

List<CalendarDate> _monthStarts(
  CalendarDate first,
  CalendarDate last,
  int step,
) {
  var index = first.year * 12 + first.month - 1;
  if (first.day > 1) index++;
  index += (step - index % step) % step;
  final out = <CalendarDate>[];
  for (; ; index += step) {
    final t = CalendarDate(index ~/ 12, index % 12 + 1, 1);
    if (t.isAfter(last)) return out;
    out.add(t);
  }
}

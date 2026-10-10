import 'package:drift/drift.dart';

class CalendarDate implements Comparable<CalendarDate> {
  final int year;
  final int month;
  final int day;

  CalendarDate(this.year, this.month, this.day) {
    if (month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month)) {
      throw ArgumentError('Invalid calendar date: $year-$month-$day');
    }
  }

  factory CalendarDate.fromDateTime(DateTime d) =>
      CalendarDate(d.year, d.month, d.day);

  factory CalendarDate.today({DateTime? now}) =>
      CalendarDate.fromDateTime(now ?? DateTime.now());

  factory CalendarDate.parse(String s) {
    final m = _isoDate.firstMatch(s);
    if (m != null) {
      return CalendarDate(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
      );
    }
    return CalendarDate.fromDateTime(DateTime.parse(s));
  }

  static final _isoDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  DateTime toDateTime() => DateTime(year, month, day);

  DateTime toUtcDateTime() => DateTime.utc(year, month, day);

  CalendarDate addDays(int n) =>
      CalendarDate.fromDateTime(DateTime.utc(year, month, day + n));

  CalendarDate addMonthsClamped(int n) {
    final total = month - 1 + n;
    final y = year + (total / 12).floor();
    final m = total % 12 + 1;
    final last = daysInMonth(y, m);
    return CalendarDate(y, m, day > last ? last : day);
  }

  int daysUntil(CalendarDate other) =>
      other.toUtcDateTime().difference(toUtcDateTime()).inDays;

  CalendarDate get startOfMonth => CalendarDate(year, month, 1);

  int get weekday => toUtcDateTime().weekday;

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;
  bool isOnOrBefore(CalendarDate other) => compareTo(other) <= 0;
  bool isOnOrAfter(CalendarDate other) => compareTo(other) >= 0;

  @override
  int compareTo(CalendarDate other) {
    final y = year.compareTo(other.year);
    if (y != 0) return y;
    final m = month.compareTo(other.month);
    return m != 0 ? m : day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

class CalendarDateConverter extends TypeConverter<CalendarDate, String> {
  const CalendarDateConverter();

  @override
  CalendarDate fromSql(String fromDb) => CalendarDate.parse(fromDb);

  @override
  String toSql(CalendarDate value) => value.toIso();
}

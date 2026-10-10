import 'calendar_date.dart';

enum DateFormatOption {
  ymd('ymd', 'YYYY-MM-DD'),
  dmy('dmy', 'DD/MM/YYYY'),
  mdy('mdy', 'MM/DD/YYYY');

  final String storageValue;
  final String label;
  const DateFormatOption(this.storageValue, this.label);

  static DateFormatOption fromStorage(String? value) => switch (value) {
    'dmy' => DateFormatOption.dmy,
    'mdy' => DateFormatOption.mdy,
    _ => DateFormatOption.ymd,
  };
}

class DateTimeFormatPrefs {
  final DateFormatOption dateFormat;
  final bool use24HourTime;

  const DateTimeFormatPrefs({
    required this.dateFormat,
    required this.use24HourTime,
  });

  static const defaults = DateTimeFormatPrefs(
    dateFormat: DateFormatOption.ymd,
    use24HourTime: true,
  );

  String _pad2(int n) => n.toString().padLeft(2, '0');

  String formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = _pad2(d.month);
    final day = _pad2(d.day);
    return switch (dateFormat) {
      DateFormatOption.ymd => '$y-$m-$day',
      DateFormatOption.dmy => '$day/$m/$y',
      DateFormatOption.mdy => '$m/$day/$y',
    };
  }

  String formatCalendarDate(CalendarDate d) => formatDate(d.toDateTime());

  String formatTime(DateTime d) {
    if (use24HourTime) return '${_pad2(d.hour)}:${_pad2(d.minute)}';
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '$hour12:${_pad2(d.minute)} $period';
  }

  String formatDateTime(DateTime d) => '${formatDate(d)} ${formatTime(d)}';
}

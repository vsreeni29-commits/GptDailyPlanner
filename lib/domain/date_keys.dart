DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String dateKey(DateTime value) {
  final date = dateOnly(value);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

DateTime dateFromKey(String value) {
  final parts = value.split('-');
  if (parts.length != 3) {
    throw FormatException('Invalid date key: $value');
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime atMinute(DateTime date, int minute) =>
    dateOnly(date).add(Duration(minutes: minute));

int minuteOfDay(DateTime value) => value.hour * 60 + value.minute;

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime startOfWeek(DateTime value) =>
    dateOnly(value).subtract(Duration(days: value.weekday - DateTime.monday));

DateTime maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

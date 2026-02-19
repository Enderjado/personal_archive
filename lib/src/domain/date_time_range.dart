/// Inclusive range of dates for filtering (e.g. created_at between start and end).
class DateTimeRange {
  const DateTimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

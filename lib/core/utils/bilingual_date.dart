// lib/core/utils/bilingual_date.dart
//
// Short date/time labels (chat timestamps, ticket dates) that follow the
// app's language instead of always rendering Arabic month names.

const _monthsAr = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _monthName(int month, String lang) =>
    (lang == 'ar' ? _monthsAr : _monthsEn)[month - 1];

/// "20 يوليو 2026" / "20 Jul 2026"
String formatShortDate(DateTime dt, String lang) =>
    '${dt.day} ${_monthName(dt.month, lang)} ${dt.year}';

/// "20 يوليو 14:05" / "20 Jul 14:05"
String formatShortDateTime(DateTime dt, String lang) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.day} ${_monthName(dt.month, lang)} $h:$m';
}

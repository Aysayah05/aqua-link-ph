import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat _peso = NumberFormat('#,##0.00', 'en_PH');
  static final DateFormat _dateFmt = DateFormat('MMM d, yyyy');
  static final DateFormat _dateTimeFmt = DateFormat('MMM d, yyyy · h:mm a');
  static final DateFormat _timeFmt = DateFormat('h:mm a');

  static String peso(num amount) => '₱${_peso.format(amount)}';

  static String date(DateTime dt) => _dateFmt.format(dt);

  static String dateTime(DateTime dt) => _dateTimeFmt.format(dt);

  static String time(DateTime dt) => _timeFmt.format(dt);

  static String monthYear(DateTime dt) => DateFormat('MMMM yyyy').format(dt);

  static String shortDate(DateTime dt) => DateFormat('MMMd').format(dt);

  static String timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return date(dt);
  }
}

extension DateOnly on DateTime {
  DateTime get dateOnly => DateTime(year, month, day);
}

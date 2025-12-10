import 'package:intl/intl.dart';

class DateFormatter {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  static String toApiFormat(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    return _dateFormat.format(localDate);
  }

  static DateTime? fromApiFormat(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return _dateFormat.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  static String formatCurrency(double value) {
    final format = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return format.format(value);
  }
}

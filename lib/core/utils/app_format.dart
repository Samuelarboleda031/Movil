import 'package:intl/intl.dart';

class AppFormat {
  /// Formateador para moneda Colombiana (COP)
  /// Ejemplo: 55000 -> $55.000
  static final NumberFormat _copFormatter = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String formatCurrency(double amount) {
    return _copFormatter.format(amount);
  }

  /// Alias más corto si prefieres
  static String cop(double amount) => formatCurrency(amount);

  /// Convierte una hora militar "HH:mm" o "HH:mm:ss" a formato 12h "hh:mm AM/PM"
  static String to12h(String time) {
    if (time.isEmpty) return '--:--';
    try {
      final parts = time.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour == 0) hour = 12;
      if (hour > 12) hour -= 12;
      return '${hour.toString().padLeft(2, '0')}:$minute $period';
    } catch (_) {
      return time;
    }
  }
}

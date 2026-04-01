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
}

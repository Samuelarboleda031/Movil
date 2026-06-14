import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/logger.dart';

/// Descuentos por día.
///
/// Se persisten en el backend (tabla DescuentosDia) para que se sincronicen
/// entre la app móvil y el panel web. Antes se guardaban en SharedPreferences,
/// por lo que cada dispositivo tenía sus propios datos aislados.
class DayDiscountService {
  static final AuthService _authService = AuthService();

  static Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Clave de fecha en formato "yyyy-MM-dd" (zona horaria local del dispositivo).
  static String fechaKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Devuelve el porcentaje de descuento de una fecha puntual (0 si no tiene).
  static Future<double> getDiscount(String fecha) async {
    final all = await getAllDiscounts();
    return all[fecha] ?? 0;
  }

  /// Crea/actualiza el descuento de un día. Si el porcentaje es <= 0, lo elimina.
  static Future<void> setDiscount(String fecha, double porcentaje) async {
    try {
      final headers = await _getHeaders();
      if (porcentaje <= 0) {
        await http.delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.descuentosDia}/$fecha'),
          headers: headers,
        );
      } else {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.descuentosDia}'),
          headers: headers,
          body: jsonEncode({'fecha': fecha, 'porcentaje': porcentaje}),
        );
      }
    } catch (e) {
      logD('❌ [DayDiscountService] Error guardando descuento: $e');
      rethrow;
    }
  }

  /// Devuelve el mapa { "yyyy-MM-dd": porcentaje } con todos los descuentos.
  static Future<Map<String, double>> getAllDiscounts() async {
    try {
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.descuentosDia}'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic raw = jsonDecode(response.body);
        if (raw is Map) {
          final result = <String, double>{};
          raw.forEach((key, value) {
            result[key.toString()] = (value is num) ? value.toDouble() : 0;
          });
          return result;
        }
      }
      return {};
    } catch (e) {
      logD('❌ [DayDiscountService] Error obteniendo descuentos: $e');
      return {};
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  static Map<String, double> _localCache = {};
  static bool _isCacheInitialized = false;

  static const String _cacheKey = 'day_discounts_cache';

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

  static Future<void> _initCache() async {
    if (_isCacheInitialized) return;
    
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(_cacheKey);
    if (cachedJson != null && cachedJson.isNotEmpty) {
      try {
        final raw = jsonDecode(cachedJson) as Map;
        _localCache = raw.map((key, value) => MapEntry(key.toString(), (value is num) ? value.toDouble() : 0));
      } catch (e) {
        logD('⚠️ [DayDiscountService] Error loading cache: $e');
      }
    }
    _isCacheInitialized = true;
  }

  static Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = jsonEncode(_localCache);
    await prefs.setString(_cacheKey, jsonStr);
  }

  /// Devuelve el porcentaje de descuento de una fecha puntual (0 si no tiene).
  static Future<double> getDiscount(String fecha) async {
    await _initCache();
    return _localCache[fecha] ?? 0;
  }

  /// Crea/actualiza el descuento de un día. Si el porcentaje es <= 0, lo elimina.
  static Future<void> setDiscount(String fecha, double porcentaje) async {
    await _initCache();
    
    // Asegurar que el descuento no supere el 100%
    final porcentajeValido = porcentaje.clamp(0.0, 100.0);
    
    // Actualizar caché local primero para UI instantánea
    if (porcentajeValido <= 0) {
      _localCache.remove(fecha);
    } else {
      _localCache[fecha] = porcentajeValido;
    }
    await _saveCache();

    // Luego sincronizar con API en segundo plano
    try {
      final headers = await _getHeaders();
      if (porcentajeValido <= 0) {
        await http.delete(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.descuentosDia}/$fecha'),
          headers: headers,
        );
      } else {
        await http.put(
          Uri.parse('${ApiConfig.baseUrl}${ApiConfig.descuentosDia}'),
          headers: headers,
          body: jsonEncode({'fecha': fecha, 'porcentaje': porcentajeValido}),
        );
      }
    } catch (e) {
      logD('❌ [DayDiscountService] Error guardando descuento en API: $e');
      // No rethrow porque ya guardamos localmente
    }
  }

  /// Devuelve el mapa { "yyyy-MM-dd": porcentaje } con todos los descuentos.
  static Future<Map<String, double>> getAllDiscounts() async {
    await _initCache();

    // Intentar actualizar desde API en segundo plano
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
          // Actualizar caché con datos frescos
          _localCache = result;
          await _saveCache();
        }
      }
    } catch (e) {
      logD('❌ [DayDiscountService] Error obteniendo descuentos de API: $e');
      // Devolver caché local si API falla
    }
    
    return Map.from(_localCache);
  }

  /// Limpia la caché (para cierre de sesión, etc.)
  static Future<void> clearCache() async {
    _localCache = {};
    _isCacheInitialized = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/logger.dart';

class DevolucionService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Registra una devolución simple. [barberoId] debe enviarse cuando la venta
  /// original fue con crédito de barbero, para que la API descuente la deuda.
  Future<Map<String, dynamic>?> registrarDevolucion({
    required int usuarioId,
    required int productoId,
    required int cantidad,
    int? ventaId,
    int? clienteId,
    int? barberoId,
    String? motivoCategoria,
    String? motivoDetalle,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = <String, dynamic>{
        'UsuarioId': usuarioId,
        'ProductoId': productoId,
        'Cantidad': cantidad,
        if (ventaId != null) 'VentaId': ventaId,
        if (clienteId != null) 'ClienteId': clienteId,
        if (barberoId != null) 'BarberoId': barberoId,
        if (motivoCategoria != null) 'MotivoCategoria': motivoCategoria,
        if (motivoDetalle != null) 'MotivoDetalle': motivoDetalle,
      };
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.devoluciones}'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      throw Exception('Error al registrar devolución: ${response.statusCode}');
    } catch (e) {
      logD('Error al registrar devolución: $e');
      rethrow;
    }
  }

  Future<double> obtenerSaldoAFavor(int clienteId) async {
    try {
      final headers = await _getHeaders();
      // Usa el endpoint dedicado que devuelve el saldo disponible real
      // (total devoluciones - total ya usado en ventas)
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/$clienteId/saldo-disponible';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        // La API retorna: { clienteId, totalDevoluciones, totalUsado, disponible }
        return (data['disponible'] ?? data['Disponible'] ?? 0).toDouble();
      }
      return 0;
    } catch (e) {
      logD('Error al obtener saldo a favor: $e');
      return 0;
    }
  }
}

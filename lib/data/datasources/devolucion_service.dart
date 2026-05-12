import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class DevolucionService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<double> obtenerSaldoAFavor(int clienteId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}/Devoluciones/cliente/$clienteId';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> items = [];

        if (rawData is List) {
          items = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          items = rawData['items'];
        }

        double totalSaldo = 0;
        for (var item in items) {
          // Solo sumar si la devolución está activa/completada
          final estado = (item['estado'] ?? item['Estado'] ?? '').toString().toLowerCase();
          if (estado != 'anulado' && estado != 'anulada') {
            totalSaldo += (item['saldoAFavor'] ?? item['SaldoAFavor'] ?? 0).toDouble();
          }
        }
        return totalSaldo;
      }
      return 0;
    } catch (e) {
      print('Error al obtener saldo a favor: $e');
      return 0;
    }
  }
}

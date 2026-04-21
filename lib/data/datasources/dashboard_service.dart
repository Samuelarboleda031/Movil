import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class DashboardService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> obtenerDashboard() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}/Dashboard';
      final response = await http.get(Uri.parse(url), headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener dashboard: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fallo de red al obtener dashboard: $e');
    }
  }

  Future<Map<String, dynamic>> obtenerGanancias(String periodo, String barbero) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}/Dashboard/ganancias').replace(queryParameters: {
        'periodo': periodo,
        'barbero': barbero,
      });
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al obtener ganancias: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fallo de red al obtener ganancias: $e');
    }
  }
}

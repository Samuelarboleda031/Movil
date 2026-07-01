import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/models/gasto_externo.dart';

class GastoExternoService {
  final AuthService _authService = AuthService();
  static const String _base = '/GastosExternos';

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<ResumenDia> obtenerResumenDia(String fecha) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.dashboard}/resumen-dia?fecha=$fecha'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return ResumenDia.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al obtener resumen: ${response.statusCode}');
  }

  Future<GastoExterno> crear(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}$_base'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return GastoExterno.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al crear gasto: ${response.statusCode} - ${response.body}');
  }

  Future<GastoExterno> actualizar(int id, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}$_base/$id'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return GastoExterno.fromJson(jsonDecode(response.body));
    }
    throw Exception('Error al actualizar gasto: ${response.statusCode}');
  }

  Future<List<GastoExterno>> obtenerPorRango(String from, String to) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}$_base/rango?from=$from&to=$to'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.map((g) => GastoExterno.fromJson(g)).toList();
    }
    throw Exception('Error al obtener gastos por rango: ${response.statusCode}');
  }

  Future<void> eliminar(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}$_base/$id'),
      headers: headers,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Error al eliminar gasto: ${response.statusCode}');
    }
  }
}

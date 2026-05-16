import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class ClienteService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Cliente>> obtenerClientes({
    int page = 1,
    int pageSize = 1000,
  }) async {
    try {
      final headers = await _getHeaders();
      final url =
          '${ApiConfig.baseUrl}${ApiConfig.clientes}?page=$page&pageSize=$pageSize';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                'Tiempo de espera agotado. Verifique su conexión a internet.',
              );
            },
          );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);

        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        } else {
          data = [];
        }

        return data.map((json) => Cliente.fromJson(json)).toList();
      } else {
        throw Exception(
          'Error al obtener clientes: ${response.statusCode} - ${response.body}',
        );
      }
    } on FormatException catch (e) {
      throw Exception('Error al procesar la respuesta de la API: $e');
    } catch (e) {
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('Failed to connect') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception(
          'No se pudo conectar con el servidor. Verifique su conexión a internet y que la API esté disponible.',
        );
      }
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Cliente> crearCliente(Cliente cliente) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
          'Error al crear cliente: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión al crear cliente: $e');
    }
  }

  Future<Cliente> actualizarCliente(Cliente cliente) async {
    if (cliente.id == null || cliente.id == 0) {
      throw Exception('No se puede actualizar un cliente sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/${cliente.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return cliente;
      } else {
        throw Exception(
          'Error al actualizar cliente: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar cliente: $e');
    }
  }

  Future<Cliente?> obtenerClientePorUsuarioId(int usuarioId) async {
    final clientes = await obtenerClientes();
    try {
      return clientes.firstWhere((c) => c.usuarioId == usuarioId);
    } catch (_) {
      return null;
    }
  }

  Future<Cliente?> obtenerClientePorId(int clienteId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/$clienteId';

      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          return Cliente.fromJson(raw);
        }
      }

      // Fallback por compatibilidad cuando el endpoint de detalle no está disponible.
      final clientes = await obtenerClientes(page: 1, pageSize: 1000);
      for (final c in clientes) {
        if (c.id == clienteId) return c;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<double> obtenerSaldoAFavor(int clienteId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/$clienteId/saldo-disponible';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final raw = jsonDecode(response.body);
        if (raw is Map) {
          final val = raw['disponible'] ?? raw['Disponible'] ?? 0;
          return (val as num).toDouble();
        }
      }
      return 0.0;
    } catch (_) {
      return 0.0;
    }
  }
}

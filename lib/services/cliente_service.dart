import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/cliente.dart';

class ClienteService {
  Future<List<Cliente>> obtenerClientes() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}?pageSize=1000';

    try {
      final response = await http.get(Uri.parse(url));

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
        throw Exception('Error al obtener clientes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener clientes: $e');
    }
  }

  Future<Cliente?> obtenerClientePorUsuarioId(int usuarioId) async {
    final clientes = await obtenerClientes();
    try {
      return clientes.firstWhere(
        (c) => c.usuarioId == usuarioId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Cliente?> obtenerClientePorEmail(String email) async {
    final clientes = await obtenerClientes();
    try {
      return clientes.firstWhere(
        (c) => (c.email ?? '').toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Cliente> crearCliente(Cliente cliente) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}';

    try {
      print('[ClienteService] POST $url');
      print('[ClienteService] Body: ${jsonEncode(cliente.toJson())}');

      final response = await http.post(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(cliente.toJson()),
      );

      print('[ClienteService] Status: ${response.statusCode}');
      print('[ClienteService] Response: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear cliente: $e');
    }
  }

  Future<Cliente> actualizarCliente(Cliente cliente) async {
    if (cliente.id == null || cliente.id == 0) {
      throw Exception('No se puede actualizar un cliente sin ID');
    }

    final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/${cliente.id}';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return cliente;
      } else {
        throw Exception('Error al actualizar cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar cliente: $e');
    }
  }
}

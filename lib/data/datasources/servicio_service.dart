import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class ServicioService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Servicio>> obtenerServicios({int page = 1, int pageSize = 1000}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}?page=$page&pageSize=$pageSize';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado. Verifique su conexión a internet.');
        },
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);
        
        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map) {
          if (rawData.containsKey('items') && rawData['items'] is List) {
            data = rawData['items'];
          } else if (rawData.containsKey('Items') && rawData['Items'] is List) {
            data = rawData['Items'];
          } else if (rawData.containsKey('data') && rawData['data'] is List) {
            data = rawData['data'];
          } else if (rawData.containsKey('Data') && rawData['Data'] is List) {
            data = rawData['Data'];
          } else {
            final List<dynamic>? firstList = rawData.values
                .firstWhere((v) => v is List, orElse: () => null) as List<dynamic>?;
            data = firstList ?? [];
          }
        } else {
          data = [];
        }

        return data.map((json) => Servicio.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener servicios: ${response.statusCode} - ${response.body}');
      }
    } on FormatException catch (e) {
      throw Exception('Error al procesar la respuesta de la API: $e');
    } catch (e) {
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Failed to connect') ||
          e.toString().contains('Failed to fetch')) {
        throw Exception('No se pudo conectar con el servidor. Verifique su conexión a internet y que la API esté disponible.');
      }
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Servicio> crearServicio(Servicio servicio) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(servicio.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Servicio.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear servicio: $e');
    }
  }

  Future<Servicio> actualizarServicio(Servicio servicio) async {
    if (servicio.id == null || servicio.id == 0) {
      throw Exception('No se puede actualizar un servicio sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}/${servicio.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(servicio.toJson()),
      );

      if (response.statusCode == 200) {
        return Servicio.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return servicio;
      } else {
        throw Exception('Error al actualizar servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar servicio: $e');
    }
  }

  Future<void> eliminarServicio(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar servicio: $e');
    }
  }

  Future<void> cambiarEstadoServicio(int id, bool estado) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}/$id/estado';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({'estado': estado}),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cambiar estado: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cambiar estado del servicio: $e');
    }
  }
}

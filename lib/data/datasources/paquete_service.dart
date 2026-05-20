import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class PaqueteService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Paquete>> obtenerPaquetes() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}?page=1&pageSize=1000';
      
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

        return data.map((json) => Paquete.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener paquetes: ${response.statusCode} - ${response.body}');
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

  Future<bool> crearPaqueteCompleto({
    required String nombre,
    required String? descripcion,
    required double precio,
    required int duracionMinutos,
    required List<Map<String, dynamic>> detalles,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}/completo';
      
      final payload = {
        'Nombre': nombre,
        'Descripcion': descripcion,
        'Precio': precio,
        'DuracionMinutos': duracionMinutos,
        'Detalles': detalles.map((d) => {
          'ServicioId': d['servicioId'] ?? d['ServicioId'],
          'Cantidad': d['cantidad'] ?? d['Cantidad'] ?? 1,
        }).toList(),
      };

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception('Error al crear paquete: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear paquete: $e');
    }
  }

  Future<bool> actualizarPaquete(Paquete paquete) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}/${paquete.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(paquete.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Error al actualizar paquete: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar paquete: $e');
    }
  }

  Future<bool> actualizarPaqueteDetalles(int paqueteId, List<Map<String, dynamic>> detalles) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}/$paqueteId/detalles';

      final payload = {
        'Detalles': detalles.map((d) => {
          'ServicioId': d['servicioId'] ?? d['ServicioId'],
          'Cantidad': d['cantidad'] ?? d['Cantidad'] ?? 1,
        }).toList(),
      };

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Error al actualizar detalles de paquete: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar detalles: $e');
    }
  }

  Future<bool> cambiarEstadoPaquete(int paqueteId, bool estado) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}/$paqueteId/estado';

      final payload = {
        'estado': estado,
      };

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Error al cambiar estado de paquete: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al cambiar estado: $e');
    }
  }

  Future<bool> eliminarPaquete(int paqueteId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}/$paqueteId';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        throw Exception('Error al eliminar paquete: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar paquete: $e');
    }
  }

  Future<List<Map<String, dynamic>>> obtenerDetallesPorPaquete(int paqueteId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}/DetallePaquetes/paquete/$paqueteId?page=1&pageSize=1000';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> items = [];
        if (rawData is List) {
          items = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          items = rawData['items'];
        } else if (rawData is Map && rawData.containsKey('Items')) {
          items = rawData['Items'];
        }

        return items.map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        throw Exception('Error al obtener detalles: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener detalles de paquete: $e');
    }
  }
}


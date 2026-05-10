import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/venta.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class VentaService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Paginacion<Venta>> obtenerVentas({int page = 1, int pageSize = 15}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.ventas}?page=$page&pageSize=$pageSize';
      
      print('🔍 Intentando conectar a: $url');
      
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
        final dynamic rawData = jsonDecode(response.body);
        
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          return Paginacion<Venta>.fromJson(rawData, (j) => Venta.fromJson(j));
        } else if (rawData is List) {
          return Paginacion<Venta>(
            items: rawData.map((j) => Venta.fromJson(j)).toList(),
            totalCount: rawData.length,
            pageSize: rawData.length,
            currentPage: 1,
            totalPages: 1,
            hasPreviousPage: false,
            hasNextPage: false,
          );
        }
        throw Exception('Formato de respuesta desconocido');
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } on FormatException catch (e) {
      print('❌ Error de formato JSON: $e');
      throw Exception('Error al procesar la respuesta de la API (formato JSON inválido): $e');
    } on http.ClientException catch (e) {
      print('❌ Error de cliente HTTP: $e');
      String errorMessage = 'Error de conexión HTTP: $e';
      
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('CORS') ||
          e.toString().contains('Access-Control-Allow-Origin')) {
        errorMessage = 'Error de CORS: El servidor no permite peticiones desde el navegador. '
            'Solución: Ejecuta la app en un dispositivo móvil o usa Chrome con CORS deshabilitado para desarrollo. '
            'Ver CORS_SOLUTION.md para más detalles.';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      print('❌ Error general: $e');
      print('❌ Tipo de error: ${e.runtimeType}');
      
      String errorMessage = 'Error: $e';
      
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('CORS') ||
          e.toString().contains('Access-Control-Allow-Origin')) {
        errorMessage = 'Error de CORS: El servidor no permite peticiones desde el navegador. '
            'Solución: Ejecuta la app en un dispositivo móvil o usa Chrome con CORS deshabilitado para desarrollo. '
            'Ver CORS_SOLUTION.md para más detalles.';
      }
      
      throw Exception(errorMessage);
    }
  }

  Future<Venta> obtenerVentaPorId(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.ventas}/$id';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Venta.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al obtener venta ID $id: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener venta: $e');
    }
  }

  Future<Venta> crearVenta(Venta venta) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(venta.toJson());
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ventas}');
      
      print('📤 Enviando a $url | Body: $body'); // Agregado log de envío

      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      
      print('Respuesta del servidor: ${response.statusCode} - ${response.body}'); // Agregado log de respuesta

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Venta.fromJson(jsonDecode(response.body));
      } else {
        // Mejor manejo de error incluyendo el cuerpo de la respuesta
        throw Exception('Error al crear venta: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Excepción al crear venta: $e');
      throw Exception('Error de conexión al crear venta: $e');
    }
  }

  Future<void> anularVenta(int id) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ventas}/$id/anular');

      final response = await http.post(
        url,
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al anular venta ID $id: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al anular venta: $e');
    }
  }
  Future<List<DetalleVenta>> obtenerDetallesVenta(int ventaId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.detalleVenta}/venta/$ventaId';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
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

        return data.map((json) => DetalleVenta.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener detalles: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener detalles: $e');
    }
  }
}
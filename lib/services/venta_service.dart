import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/venta.dart';
import '../services/auth_service.dart';

class VentaService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Venta>> obtenerVentas() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.ventas}?pageSize=1000';
      
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

      print('📥 Status Code: ${response.statusCode}');
      
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

        return data.map((json) => Venta.fromJson(json)).toList();
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body.length > 100 ? response.body.substring(0, 100) : response.body}');
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

  Future<Venta> actualizarVenta(Venta venta) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode(venta.toJson());
      final url = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.ventas}/${venta.id}');

      final response = await http.put(
        url,
        headers: headers,
        body: body,
      );
      
      print('Respuesta del servidor PUT: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return Venta.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return venta;
      } else {
        // Mejor manejo de error incluyendo el cuerpo de la respuesta
        throw Exception('Error al actualizar venta ID ${venta.id}: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar venta: $e');
    }
  }

  Future<void> eliminarVenta(int id) async {
    try {
      // Soft delete: Update estado to false
      final venta = await obtenerVentaPorId(id);
      
      // Create a copy with estado = false
      final ventaDesactivada = Venta(
        id: venta.id,
        numero: venta.numero,
        fechaRegistro: venta.fechaRegistro,
        clienteId: venta.clienteId,
        barberoId: venta.barberoId,
        metodoPago: venta.metodoPago,
        subtotal: venta.subtotal,
        porcentajeDescuento: venta.porcentajeDescuento,
        total: venta.total,
        estado: 'Cancelada', // Soft delete / Anular
        detalles: venta.detalles,
      );

      await actualizarVenta(ventaDesactivada);
      
    } catch (e) {
      throw Exception('Error al eliminar venta: $e');
    }
  }
  Future<List<DetalleVenta>> obtenerDetallesVenta(int ventaId) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.detalleVenta}?pageSize=5000'; // Muchos detalles posibles
      
      print('🔍 Consultando detalles en: $url');

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

        final todosLosDetalles = data.map((json) => DetalleVenta.fromJson(json)).toList();
        
        // Filtrar por ventaId en el cliente
        return todosLosDetalles.where((d) => d.ventaId == ventaId).toList();
      } else {
        throw Exception('Error al obtener detalles: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error obteniendo detalles: $e');
      // Retornar lista vacía en vez de error para no bloquear la UI principal, 
      // pero idealmente deberíamos propagar el error o manejarlo en la UI.
      // Por ahora propagamos para mostrar el snackbar.
      throw Exception('Error de conexión al obtener detalles: $e');
    }
  }
}
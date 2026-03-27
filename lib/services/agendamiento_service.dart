import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/agendamiento.dart';
import '../services/auth_service.dart';

class AgendamientoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Agendamiento>> obtenerAgendamientos() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}?pageSize=1000';
      
      print('🔍 [AgendamientoService] Intentando conectar a: $url');
      
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
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        } else if (rawData is Map && rawData.containsKey('data')) {
          data = rawData['data'];
        } else {
          data = [];
        }

        return data.map<Agendamiento>((json) => Agendamiento.fromJson(json)).toList();
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ [AgendamientoService] Error general: $e');
      throw Exception('Error al obtener agendamientos: $e');
    }
  }

  Future<Agendamiento> obtenerAgendamientoPorId(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return Agendamiento.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al obtener agendamiento: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Agendamiento> crearAgendamiento(Agendamiento agendamiento) async {
    try {
      final headers = await _getHeaders();
      final payload = agendamiento.toJson();
      print('📤 [AgendamientoService] Enviando payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}'),
        headers: headers,
        body: jsonEncode(payload),
      );

      print('📥 [AgendamientoService] Respuesta ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Agendamiento.fromJson(jsonDecode(response.body));
      } else {
        // Extraer mensaje del servidor para mostrar al usuario
        String serverMsg = response.body;
        try {
          final parsed = jsonDecode(response.body);
          serverMsg = parsed['message'] ?? parsed['error'] ?? parsed['title'] ?? serverMsg;
        } catch (_) {}
        throw Exception('Error ${response.statusCode}: $serverMsg');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Agendamiento> actualizarAgendamiento(Agendamiento agendamiento) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/${agendamiento.id}'),
        headers: headers,
        body: jsonEncode(agendamiento.toJson()),
      );

      if (response.statusCode == 200) {
        return Agendamiento.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return agendamiento;
      } else {
        throw Exception('Error al actualizar agendamiento: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> eliminarAgendamiento(int id) async {
    try {
      final headers = await _getHeaders();
      
      // Log the deletion for debugging
      print('Eliminando agendamiento $id');
      
      // Send DELETE request to the server
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar el agendamiento: ${response.statusCode}');
      }
      
      print('Agendamiento $id eliminado exitosamente');
      
    } catch (e) {
      print('Error en eliminarAgendamiento: $e');
      throw Exception('Error al eliminar agendamiento: $e');
    }
  }

  Future<List<Agendamiento>> obtenerAgendamientosPorCliente(int clienteId) async {
    try {
      final headers = await _getHeaders();
      // Siguiendo el ejemplo de Front4: /Agendamientos/cliente/{id}
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/cliente/$clienteId?pageSize=100';
           
      print('🔍 [AgendamientoService] Obteniendo citas para el cliente: $clienteId');
      print('🔗 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado. Verifique su conexión a internet.');
        },
      );

      print('📥 [AgendamientoService] Status Code: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('ℹ️ [AgendamientoService] El cliente no tiene citas agendadas');
          return [];
        }
        
        try {
          final dynamic responseData = jsonDecode(response.body);
          
          if (responseData is List) {
            print('✅ [AgendamientoService] Se encontraron ${responseData.length} citas para el cliente');
            return responseData.map<Agendamiento>((json) => Agendamiento.fromJson(json)).toList();
          } else if (responseData is Map && responseData.containsKey('data')) {
            final data = responseData['data'] as List;
            print('✅ [AgendamientoService] Se encontraron ${data.length} citas para el cliente en la propiedad data');
            return data.map<Agendamiento>((json) => Agendamiento.fromJson(json)).toList();
          } else {
            // If we get here, the API returned a 200 but with an unexpected format
            // Let's try to get all appointments and filter client-side as a fallback
            print('⚠️ [AgendamientoService] Formato de respuesta inesperado, intentando filtrado local...');
            final allAppointments = await obtenerAgendamientos();
            final clientAppointments = allAppointments
                .where((appointment) => appointment.clienteId == clienteId)
                .toList();
            print('✅ [AgendamientoService] Se encontraron ${clientAppointments.length} citas para el cliente (filtrado local)');
            return clientAppointments;
          }
        } catch (e) {
          print('❌ [AgendamientoService] Error al procesar la respuesta: $e');
          rethrow;
        }
      } else {
        // If we get a 404 or other error, try to get all appointments and filter client-side
        print('⚠️ [AgendamientoService] Error ${response.statusCode} al obtener citas, intentando filtrado local...');
        try {
          final allAppointments = await obtenerAgendamientos();
          final clientAppointments = allAppointments
              .where((appointment) => appointment.clienteId == clienteId)
              .toList();
          print('✅ [AgendamientoService] Se encontraron ${clientAppointments.length} citas para el cliente (filtrado local)');
          return clientAppointments;
        } catch (e) {
          print('❌ [AgendamientoService] Error en el filtrado local: $e');
          throw Exception('No se pudieron cargar las citas. Por favor, intente nuevamente.');
        }
      }
    } on FormatException catch (e) {
      print('❌ Error de formato JSON: $e');
      throw Exception('Error al procesar la respuesta de la API (formato JSON inválido): $e');
    } catch (e) {
      print('❌ Error al obtener citas del cliente: $e');
      rethrow;
    }
  }
}


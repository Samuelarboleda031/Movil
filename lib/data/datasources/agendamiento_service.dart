import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/data/datasources/emailjs_service.dart';

class AgendamientoService {
  final AuthService _authService = AuthService();
  final EmailJsService _emailJsService = EmailJsService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientos({int page = 1, int pageSize = 15}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}?page=$page&pageSize=$pageSize';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Tiempo de espera agotado.');
        },
      );

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          return Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j));
        } else {
          final List<dynamic> list = rawData is List ? rawData : (rawData['items'] ?? rawData['data'] ?? []);
          return Paginacion<Agendamiento>(
            items: list.map((j) => Agendamiento.fromJson(j)).toList(),
            totalCount: list.length,
            pageSize: list.length,
            currentPage: 1,
            totalPages: 1,
            hasPreviousPage: false,
            hasNextPage: false,
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}');
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
            final allAppointmentsPaginacion = await obtenerAgendamientos(page: 1, pageSize: 5000);
            final clientAppointments = allAppointmentsPaginacion.items
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
          final allAppointmentsPaginacion = await obtenerAgendamientos(page: 1, pageSize: 5000);
          final clientAppointments = allAppointmentsPaginacion.items
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

  Future<void> cancelarAgendamiento(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id/cancelar';
      
      final response = await http.put(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar cita: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al cancelar: $e');
    }
  }

  Future<void> cancelarDiaCompleto(String fecha, {String? motivo}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/cancelar-dia/$fecha';
      final response = await http.put(Uri.parse(url), headers: headers);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar día: ${response.statusCode}');
      }

      // 2. Notificar a cada cliente leyendo la respuesta del backend
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          final List afectadosRaw = data is List ? data : (data['data'] ?? data['items'] ?? data['afectados'] ?? []);
          
          for (var cita in afectadosRaw) {
            final email = (cita['clienteCorreo'] ?? cita['ClienteCorreo'])?.toString();
            if (email != null && email.isNotEmpty) {
              final fechaOriginalApi = cita['fechaHoraOriginal'] ?? cita['FechaHoraOriginal'] ?? fecha;
              List<String>? sugerencias;
              final sugerenciasRaw = cita['sugerenciasReprogramacion'] ?? cita['SugerenciasReprogramacion'] ?? cita['sugerencias'] ?? cita['Sugerencias'];
              if (sugerenciasRaw != null && sugerenciasRaw is List) {
                sugerencias = List<String>.from(sugerenciasRaw.map((x) => x.toString()));
              }

              _emailJsService.notificarCancelacion(
                clienteNombre: (cita['clienteNombre'] ?? cita['ClienteNombre'])?.toString() ?? 'Cliente',
                clienteEmail: email,
                barberoNombre: (cita['barberoNombre'] ?? cita['BarberoNombre'])?.toString() ?? 'Tu Barbero',
                fechaOriginal: fechaOriginalApi.toString(),
                motivo: motivo ?? 'El local cerrará este día por motivos administrativos.',
                sugerenciasReprogramacion: sugerencias,
              );
            }
          }
        } catch (e) {
          print('❌ [AgendamientoService] Error al procesar notificaciones de día completo: $e');
        }
      }
    } catch (e) {
      throw Exception('Error al cancelar día: $e');
    }
  }

  Future<void> cancelarDiaBarbero({
    required int barberoId,
    required String fecha,
    required int usuarioSolicitanteId,
    String? motivo,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/barbero/$barberoId/cancelar-dia';
      final body = {
        'estado': false,
        'UsuarioSolicitanteId': usuarioSolicitanteId,
        'FechaReferencia': fecha,
        if (motivo != null) 'Motivo': motivo,
        'CantidadSugerencias': 3,
      };

      final response = await http.post(Uri.parse(url), headers: headers, body: jsonEncode(body));

      if (response.statusCode != 200 && response.statusCode != 204) {
        String errMsg = 'Error al cancelar día del barbero';
        try {
          final data = jsonDecode(response.body);
          errMsg = data['message'] ?? data['error'] ?? errMsg;
        } catch (_) {}
        throw Exception(errMsg);
      }

      // 2. Notificar a cada cliente (aprovechando datos enriquecidos retornados por API)
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        try {
          final data = jsonDecode(response.body);
          final List afectadosRaw = data is List ? data : (data['data'] ?? data['items'] ?? data['afectados'] ?? []);
          
          for (var cita in afectadosRaw) {
            final email = (cita['clienteCorreo'] ?? cita['ClienteCorreo'])?.toString();
            if (email != null && email.isNotEmpty) {
              final fechaOriginalApi = cita['fechaHoraOriginal'] ?? cita['FechaHoraOriginal'] ?? fecha;
              List<String>? sugerencias;
              final sugerenciasRaw = cita['sugerenciasReprogramacion'] ?? cita['SugerenciasReprogramacion'] ?? cita['sugerencias'] ?? cita['Sugerencias'];
              if (sugerenciasRaw != null && sugerenciasRaw is List) {
                sugerencias = List<String>.from(sugerenciasRaw.map((x) => x.toString()));
              }

              _emailJsService.notificarCancelacion(
                clienteNombre: (cita['clienteNombre'] ?? cita['ClienteNombre'])?.toString() ?? 'Cliente',
                clienteEmail: email,
                barberoNombre: (cita['barberoNombre'] ?? cita['BarberoNombre'])?.toString() ?? 'Tu Barbero',
                fechaOriginal: fechaOriginalApi.toString(),
                motivo: motivo ?? 'El barbero no estará disponible este día.',
                sugerenciasReprogramacion: sugerencias,
              );
            }
          }
        } catch (e) {
          print('❌ [AgendamientoService] Error al procesar notificaciones de barbero: $e');
        }
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}


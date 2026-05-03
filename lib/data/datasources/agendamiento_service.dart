import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class AgendamientoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientos({int page = 1, int pageSize = 10, bool? estaSemana}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}?page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';
      if (estaSemana != null) {
        url += '&estaSemana=$estaSemana';
      }
      
      print('🔍 [AgendamientoService] Fetching: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
      );

      print('📥 [AgendamientoService] Response Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          final pag = Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j));
          print('✅ [AgendamientoService] Received ${pag.items.length} items');
          return pag;
        } else {
          final List<dynamic> list = rawData is List ? rawData : (rawData['items'] ?? rawData['data'] ?? []);
          print('✅ [AgendamientoService] Received ${list.length} items (legacy format)');
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
        print('❌ [AgendamientoService] Error: ${response.body}');
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
        throw Exception('Error al actualizar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> cancelarAgendamiento(int id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> actualizarEstadoAgendamiento(int id, String estado) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id/estado'),
        headers: headers,
        body: jsonEncode({'estado': estado}),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al actualizar estado: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> cancelarDiaCompleto(String fecha, {String? motivo}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/cancelar-dia?fecha=$fecha&motivo=${motivo ?? ""}'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar día: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
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
      final url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/cancelar-dia-barbero';
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'barberoId': barberoId,
          'fecha': fecha,
          'usuarioSolicitanteId': usuarioSolicitanteId,
          'motivo': motivo ?? 'Cancelación administrativa'
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cancelar día de barbero: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientosPorCliente(int clienteId, {int page = 1, int pageSize = 10, bool? estaSemana}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/cliente/$clienteId?page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';
      if (estaSemana != null) {
        url += '&estaSemana=$estaSemana';
      }
           
      print('🔍 [AgendamientoService] Obteniendo citas para el cliente: $clienteId');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
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
        throw Exception('Error al obtener citas del cliente: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al obtener citas del cliente: $e');
      rethrow;
    }
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientosPorBarbero(int barberoId, {int page = 1, int pageSize = 10, bool? estaSemana}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/barbero/$barberoId?page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';
      if (estaSemana != null) {
        url += '&estaSemana=$estaSemana';
      }
           
      print('🔍 [AgendamientoService] Obteniendo citas para el barbero: $barberoId');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
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
        throw Exception('Error al obtener citas del barbero: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al obtener citas del barbero: $e');
      rethrow;
    }
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientosPorBarberoYFecha(int barberoId, String fecha, {int page = 1, int pageSize = 50}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}/barbero/$barberoId?page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';
      
      print('🔍 [AgendamientoService] Obteniendo citas para el barbero: $barberoId en fecha: $fecha');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<Agendamiento> citas = [];
        
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          citas = Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j)).items;
        } else if (rawData is List) {
          citas = rawData.map((j) => Agendamiento.fromJson(j)).toList();
        }
        
        // Filtrar solo las citas de la fecha especificada y ordenar por hora
        final citasHoy = citas.where((c) => c.fechaCita == fecha).toList();
        citasHoy.sort((a, b) => (a.horaInicio ?? '').compareTo(b.horaInicio ?? ''));
        
        print('✅ [AgendamientoService] Encontradas ${citasHoy.length} citas para hoy');
        
        return Paginacion<Agendamiento>(
          items: citasHoy,
          totalCount: citasHoy.length,
          pageSize: citasHoy.length,
          currentPage: 1,
          totalPages: 1,
          hasPreviousPage: false,
          hasNextPage: false,
        );
      } else {
        throw Exception('Error al obtener citas del barbero: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error al obtener citas del barbero: $e');
      rethrow;
    }
  }
}

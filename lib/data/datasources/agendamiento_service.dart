import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/agendamiento.dart';
import 'package:parte_movil/data/models/paginacion.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';
import 'package:parte_movil/core/utils/logger.dart';

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
      
      logD('🔍 [AgendamientoService] Fetching: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(
        const Duration(seconds: 30),
      );

      logD('📥 [AgendamientoService] Response Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          final pag = Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j));
          logD('✅ [AgendamientoService] Received ${pag.items.length} items');
          return pag;
        } else {
          final List<dynamic> list = rawData is List ? rawData : (rawData['items'] ?? rawData['data'] ?? []);
          logD('✅ [AgendamientoService] Received ${list.length} items (legacy format)');
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
        logD('❌ [AgendamientoService] Error: ${response.body}');
        throw Exception('Error HTTP ${response.statusCode}');
      }
    } catch (e) {
      logD('❌ [AgendamientoService] Error general: $e');
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
      logD('📤 [AgendamientoService] Enviando payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}'),
        headers: headers,
        body: jsonEncode(payload),
      );

      logD('📥 [AgendamientoService] Respuesta ${response.statusCode}: ${response.body}');

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

  // Devuelve el ventaId creado (si el backend lo incluye en el response).
  Future<int?> actualizarEstadoAgendamiento(int id, String estado, {double porcentajeDescuento = 0}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id/estado'),
        headers: headers,
        body: jsonEncode({'estado': estado, 'porcentajeDescuento': porcentajeDescuento}),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al actualizar estado: ${response.statusCode} - ${response.body}');
      }

      return _extraerVentaId(response.body);
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Devuelve el ventaId creado (si el backend lo incluye en el response).
  Future<int?> completarParcialmente(int id, List<int> serviciosCompletados, List<int> productosCompletados, {double porcentajeDescuento = 0}) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/$id/completar-parcialmente'),
        headers: headers,
        body: jsonEncode({
          'serviciosCompletados': serviciosCompletados,
          'productosCompletados': productosCompletados,
          'estado': 'Completada',
          'porcentajeDescuento': porcentajeDescuento,
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al completar parcialmente: ${response.statusCode} - ${response.body}');
      }

      return _extraerVentaId(response.body);
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Intenta extraer el ID de la venta creada del cuerpo del response.
  int? _extraerVentaId(String body) {
    if (body.isEmpty) return null;
    try {
      final json = jsonDecode(body);
      if (json is Map) {
        // El backend puede devolver la venta directamente o anidada
        final ventaId = json['ventaId'] ?? json['VentaId'] ?? json['venta']?['id'] ?? json['venta']?['Id'];
        if (ventaId != null) return int.tryParse(ventaId.toString());
        // Si devuelve la venta como objeto raíz
        final id = json['id'] ?? json['Id'] ?? json['ID'];
        if (id != null && (json.containsKey('numero') || json.containsKey('Numero') ||
            json.containsKey('metodoPago') || json.containsKey('MetodoPago'))) {
          return int.tryParse(id.toString());
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<Agendamiento>> obtenerCitasPorTerminar() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.agendamientos}/por-terminar'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> list = [];
        
        if (rawData is Map<String, dynamic> && rawData.containsKey('data')) {
          list = rawData['data'] as List<dynamic>;
        } else if (rawData is List) {
          list = rawData;
        }

        return list.map((j) => Agendamiento.fromJson(j as Map<String, dynamic>)).toList();
      } else {
        throw Exception('Error al obtener citas por terminar: ${response.statusCode}');
      }
    } catch (e) {
      logD('❌ [AgendamientoService] Error en obtenerCitasPorTerminar: $e');
      return [];
    }
  }

  Future<void> cancelarDiaBarbero({
    required int barberoId,
    required int usuarioSolicitanteId,
    String? motivo,
  }) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/barbero/$barberoId/cancelar-dia';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'estado': false,
          'usuarioSolicitanteId': usuarioSolicitanteId,
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
           
      logD('🔍 [AgendamientoService] Obteniendo citas para el cliente: $clienteId');
      
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
      logD('❌ Error al obtener citas del cliente: $e');
      rethrow;
    }
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientosPorBarbero(int barberoId, {int page = 1, int pageSize = 20, bool? estaSemana}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}?barberoId=$barberoId&page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';
      if (estaSemana != null) {
        url += '&estaSemana=$estaSemana';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          return Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j));
        } else {
          final List<dynamic> list = rawData is List ? rawData : (rawData['items'] ?? rawData['data'] ?? []);
          final filtradas = list
              .map((j) => Agendamiento.fromJson(j as Map<String, dynamic>))
              .where((a) => a.barberoId == barberoId)
              .toList();
          return Paginacion<Agendamiento>(
            items: filtradas,
            totalCount: filtradas.length,
            pageSize: pageSize,
            currentPage: page,
            totalPages: 1,
            hasPreviousPage: false,
            hasNextPage: false,
          );
        }
      } else {
        throw Exception('Error al obtener citas del barbero: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Paginacion<Agendamiento>> obtenerAgendamientosPorBarberoYFecha(int barberoId, String fecha, {int page = 1, int pageSize = 50}) async {
    try {
      final headers = await _getHeaders();
      var url = '${ApiConfig.baseUrl}${ApiConfig.agendamientos}?barberoId=$barberoId&fecha=$fecha&page=$page&pageSize=$pageSize&_t=${DateTime.now().millisecondsSinceEpoch}';

      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map<String, dynamic> && rawData.containsKey('items')) {
          return Paginacion<Agendamiento>.fromJson(rawData, (j) => Agendamiento.fromJson(j));
        } else {
          final List<dynamic> list = rawData is List ? rawData : (rawData['items'] ?? rawData['data'] ?? []);
          final citasHoy = list
              .map((j) => Agendamiento.fromJson(j as Map<String, dynamic>))
              .where((c) => c.barberoId == barberoId && c.fechaCita == fecha)
              .toList();
          citasHoy.sort((a, b) => (a.horaInicio ?? '').compareTo(b.horaInicio ?? ''));
          return Paginacion<Agendamiento>(
            items: citasHoy,
            totalCount: citasHoy.length,
            pageSize: pageSize,
            currentPage: page,
            totalPages: 1,
            hasPreviousPage: false,
            hasNextPage: false,
          );
        }
      } else {
        throw Exception('Error al obtener citas del barbero: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/solicitud_cambio_horario.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class SolicitudCambioHorarioService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<SolicitudCambioHorario>> getSolicitudes({
    String? estado,
    int? barberoId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final params = <String, String>{
        'page': '$page',
        'pageSize': '$pageSize',
        if (estado != null) 'estado': estado,
        if (barberoId != null) 'barberoId': '$barberoId',
      };
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.solicitudesCambioHorario}')
          .replace(queryParameters: params);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body);
        final List<dynamic> items = raw is List ? raw : (raw['items'] ?? []);
        return items.map((j) => SolicitudCambioHorario.fromJson(j)).toList();
      }
      throw Exception('Error al obtener solicitudes: ${response.statusCode}');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<SolicitudCambioHorario> crearSolicitud({
    required int barberoId,
    required String motivoCategoria,
    String? motivoDetalle,
    required DateTime fechaReferencia,
    required List<SugerenciaHorario> sugerencias,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'barberoId': barberoId,
        'motivoCategoria': motivoCategoria,
        if (motivoDetalle != null) 'motivoDetalle': motivoDetalle,
        'fechaReferencia': fechaReferencia.toIso8601String(),
        'sugerencias': sugerencias.map((s) => s.toCreateJson()).toList(),
      });

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.solicitudesCambioHorario}'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return SolicitudCambioHorario(
          id: data['id'],
          barberoId: barberoId,
          motivoCategoria: motivoCategoria,
          motivoDetalle: motivoDetalle,
          fechaReferencia: fechaReferencia,
          estado: data['estado'] ?? 'Pendiente',
          sugerencias: sugerencias,
        );
      }
      throw Exception('Error al crear solicitud: ${response.statusCode} - ${response.body}');
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> aprobar(int id, int usuarioId) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.solicitudesCambioHorario}/$id/aprobar')
          .replace(queryParameters: {'usuarioId': '$usuarioId'});
      final response = await http.post(uri, headers: headers).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al aprobar: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> rechazar(int id, int usuarioId, {String? observacion, List<SugerenciaHorario>? sugerencias}) async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${ApiConfig.baseUrl}${ApiConfig.solicitudesCambioHorario}/$id/rechazar')
          .replace(queryParameters: {'usuarioId': '$usuarioId'});
      final body = jsonEncode({
        if (observacion != null) 'observacion': observacion,
        if (sugerencias != null && sugerencias.isNotEmpty)
          'sugerencias': sugerencias.map((s) => s.toCreateJson()).toList(),
      });
      final response = await http.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al rechazar: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  Future<void> responder(int id, bool acepta, {String? observacion}) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'acepta': acepta,
        if (observacion != null) 'observacion': observacion,
      });
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.solicitudesCambioHorario}/$id/responder'),
        headers: headers,
        body: body,
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al responder: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/horario_barbero.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class HorarioBarberoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<HorarioSemanal>> obtenerHorarios() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}?pageSize=1000';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
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

        return data
            .map((json) => HorarioSemanal.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Error al obtener horarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener horarios semanales: $e');
      return [];
    }
  }

  Future<HorarioSemanal> crearHorarioSemanal(HorarioSemanal horario) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(horario.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HorarioSemanal.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear horario semanal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear horario semanal: $e');
    }
  }

  Future<HorarioSemanal> actualizarHorarioSemanal(int id, HorarioSemanal horario) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id';

      final body = <String, dynamic>{};
      if (horario.fechaInicioSemana.isNotEmpty) body['FechaInicioSemana'] = horario.fechaInicioSemana;
      if (horario.fechaFinSemana.isNotEmpty) body['FechaFinSemana'] = horario.fechaFinSemana;
      if (horario.estado.isNotEmpty) body['Estado'] = horario.estado;
      if (horario.detalles.isNotEmpty) body['Detalles'] = horario.detalles.map((d) => d.toJson()).toList();

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        return HorarioSemanal.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return horario;
      } else {
        throw Exception('Error al actualizar horario semanal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar horario semanal: $e');
    }
  }

  Future<void> eliminarHorarioSemanal(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar horario semanal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar horario semanal: $e');
    }
  }

  Future<void> cambiarEstado(int id, bool nuevoEstado, {int usuarioSolicitanteId = 0}) async {
    try {
      final headers = await _getHeaders();

      int resolvedUserId = usuarioSolicitanteId;
      if (resolvedUserId <= 0) {
        final user = await _authService.getCurrentUser();
        resolvedUserId = user?.id ?? 0;
      }

      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id/estado';
      final payload = jsonEncode({
        'estado': nuevoEstado,
        'usuarioSolicitanteId': resolvedUserId,
      });

      final response = await http.post(Uri.parse(url), headers: headers, body: payload);

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al cambiar estado: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cambiar estado del horario semanal: $e');
    }
  }
}

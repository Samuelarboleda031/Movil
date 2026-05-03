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

  Future<List<HorarioBarbero>> obtenerHorarios() async {
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
            .map((json) => HorarioBarbero.fromJson(json as Map<String, dynamic>))
            .toList(); // Return all to allow toggling status
      } else {
        throw Exception('Error al obtener horarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener horarios de barberos: $e');
      return [];
    }
  }

  Future<HorarioBarbero> crearHorario(HorarioBarbero horario) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(horario.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return HorarioBarbero.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear horario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear horario: $e');
    }
  }

  Future<HorarioBarbero> actualizarHorario(HorarioBarbero horario) async {
    if (horario.id == null || horario.id == 0) {
      throw Exception('No se puede actualizar un horario sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/${horario.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(horario.toJson()),
      );

      if (response.statusCode == 200) {
        return HorarioBarbero.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return horario;
      } else {
        throw Exception('Error al actualizar horario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar horario: $e');
    }
  }

  Future<void> eliminarHorario(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar horario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar horario: $e');
    }
  }

  Future<HorarioBarbero> cambiarEstado(int id) async {
    try {
      final headers = await _getHeaders();
      
      // Primero obtener el horario actual para saber a qué estado cambiar
      final getUrl = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id';
      final getResp = await http.get(Uri.parse(getUrl), headers: headers);
      
      if (getResp.statusCode != 200) {
        throw Exception('No se encontró el horario para cambiar estado');
      }
      
      final horario = HorarioBarbero.fromJson(jsonDecode(getResp.body));
      final nuevoEstado = !horario.estado;

      final url = '${ApiConfig.baseUrl}${ApiConfig.horariosBarberos}/$id/estado';
      final payload = jsonEncode({ 'estado': nuevoEstado });
      
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: payload,
      );

      if (response.statusCode == 404 || response.statusCode == 405) {
        // Fallback
        final updatedHorario = HorarioBarbero(
          id: horario.id,
          barberoId: horario.barberoId,
          diaSemana: horario.diaSemana,
          horaInicio: horario.horaInicio,
          horaFin: horario.horaFin,
          estado: nuevoEstado,
        );
        return actualizarHorario(updatedHorario);
      } else if (response.statusCode == 200 || response.statusCode == 204) {
        // En caso de que sí devuelva algo el PATCH/POST
        if (response.body.isNotEmpty) {
          return HorarioBarbero.fromJson(jsonDecode(response.body));
        } else {
          // No podemos devolver el horario actualizado si el response.body está vacío.
          // Solo devolvemos un mock asumiendo que se guardó.
           throw Exception('El endpoint de estado devolvió 204 sin contenido. Se requiere recargar.');
        }
      } else {
         throw Exception('Error al cambiar estado: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al cambiar estado del horario: $e');
    }
  }
}

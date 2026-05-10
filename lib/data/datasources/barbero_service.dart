import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

import 'package:parte_movil/data/models/horario_barbero.dart';

class BarberoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<List<Barbero>> obtenerBarberos() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}?pageSize=1000';
      
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
        } else {
          data = [];
        }

        return data.map((json) => Barbero.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener barberos: ${response.statusCode} - ${response.body}');
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

  Future<Barbero> crearBarbero(Barbero barbero) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(barbero.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Barbero.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear barbero: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear barbero: $e');
    }
  }

  Future<Barbero> actualizarBarbero(Barbero barbero) async {
    if (barbero.id == null || barbero.id == 0) {
      throw Exception('No se puede actualizar un barbero sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}/${barbero.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(barbero.toJson()),
      );

      if (response.statusCode == 200) {
        return Barbero.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return barbero;
      } else {
        throw Exception('Error al actualizar barbero: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar barbero: $e');
    }
  }

  Future<Barbero?> obtenerBarberoPorUsuarioId(int usuarioId) async {
    final barberos = await obtenerBarberos();
    try {
      return barberos.firstWhere((b) => b.usuarioId == usuarioId);
    } catch (_) {
      return null;
    }
  }

  Future<List<HorarioBarbero>> obtenerHorariosBarberos() async {
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
            .where((h) => h.estado)
            .toList();
      } else {
        throw Exception('Error al obtener horarios: ${response.statusCode}');
      }
    } catch (e) {
      print('Error al obtener horarios de barberos: $e');
      return [];
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/barbero.dart';

class BarberoService {
  Future<List<Barbero>> obtenerBarberos() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => Barbero.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener barberos: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener barberos: $e');
    }
  }

  Future<Barbero?> obtenerBarberoPorUsuarioId(int usuarioId) async {
    final barberos = await obtenerBarberos();
    try {
      return barberos.firstWhere(
        (b) => b.usuarioId == usuarioId,
      );
    } catch (_) {
      return null;
    }
  }

  Future<Barbero?> obtenerBarberoPorEmail(String email) async {
    final barberos = await obtenerBarberos();
    try {
      return barberos.firstWhere(
        (b) => (b.email ?? '').toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Barbero> crearBarbero(Barbero barbero) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}';

    try {
      print('[BarberoService] POST $url');
      print('[BarberoService] Body: ${jsonEncode(barbero.toJson())}');

      final response = await http.post(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(barbero.toJson()),
      );

      print('[BarberoService] Status: ${response.statusCode}');
      print('[BarberoService] Response: ${response.body}');

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

    final url = '${ApiConfig.baseUrl}${ApiConfig.barberos}/${barbero.id}';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
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
}

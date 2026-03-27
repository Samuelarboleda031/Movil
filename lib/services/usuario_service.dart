import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/usuario.dart';

class UsuarioService {
  Future<List<Usuario>> obtenerUsuarios() async {
    // Pedimos un pageSize alto para evitar problemas de paginación en el login por ahora
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}?pageSize=1000';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);
        
        // Manejar tanto List directo como { "items": [...] }
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

        return data.map((json) => Usuario.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener usuarios: $e');
    }
  }

  Future<Usuario?> obtenerUsuarioPorCorreo(String correo) async {
    final usuarios = await obtenerUsuarios();
    try {
      return usuarios.firstWhere(
        (u) => u.correo.toLowerCase() == correo.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Usuario> crearUsuario(Usuario usuario) async {
    
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}';

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(usuario.toJson()),
      );
print('[UsuarioService] POST $url');
    print('[UsuarioService] Status: ${response.statusCode}');
    print('[UsuarioService] Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Usuario.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear usuario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear usuario: $e');
    }
  }

  Future<Usuario> actualizarUsuario(Usuario usuario) async {
    if (usuario.id == null || usuario.id == 0) {
      throw Exception('No se puede actualizar un usuario sin ID');
    }

    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}/${usuario.id}';

    try {
      final response = await http.put(
        Uri.parse(url),
        headers: const {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(usuario.toJson()),
      );

      if (response.statusCode == 200) {
        return Usuario.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return usuario;
      } else {
        throw Exception('Error al actualizar usuario: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar usuario: $e');
    }
  }
}



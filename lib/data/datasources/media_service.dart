import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class MediaService {
  final AuthService _authService = AuthService();

  // Subir imagen genérica (Servicios, Perfiles, Productos, etc.)
  Future<String> subirImagen(String filePath, {List<int>? imageBytes, String? fileName}) async {
    try {
      final token = await _authService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}/images/subir');
      final request = http.MultipartRequest('POST', url);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      final nameToParse = fileName ?? filePath;
      String ext = 'jpeg';
      if (nameToParse.contains('.')) {
        final extParts = nameToParse.split('.').last.toLowerCase();
        if (extParts == 'png' || extParts == 'gif' || extParts == 'webp') {
          ext = extParts;
        } else if (extParts == 'jpg') {
          ext = 'jpeg';
        }
      }

      if (imageBytes != null && fileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'imagen', 
          imageBytes, 
          filename: fileName,
          contentType: MediaType('image', ext),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'imagen', 
          filePath,
          contentType: MediaType('image', ext),
        ));
      }
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic rawData = jsonDecode(response.body);
        if (rawData is Map && rawData.containsKey('url')) {
          return rawData['url'];
        }
        return rawData.toString();
      } else {
        throw Exception('Error al subir imagen: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al subir imagen: $e');
    }
  }

  // Subir foto de perfil específica para un usuario
  Future<String?> subirFotoPerfil(int usuarioId, String imagePath) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/Usuarios/$usuarioId/foto');
    final request = http.MultipartRequest('POST', uri);

    final token = await _authService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.files.add(await http.MultipartFile.fromPath('imagen', imagePath));

    final response = await request.send();
    if (response.statusCode == 200 || response.statusCode == 201) {
      final resStr = await response.stream.bytesToString();
      final data = jsonDecode(resStr);
      if (data is Map<String, dynamic> && data['fotoPerfil'] != null) {
        return data['fotoPerfil'];
      }
      return 'success';
    } else {
      final resStr = await response.stream.bytesToString();
      throw Exception('Error al subir foto: $resStr');
    }
  }
}

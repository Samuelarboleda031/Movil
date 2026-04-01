import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/cliente.dart';
import 'package:parte_movil/data/models/barbero.dart';
import 'package:parte_movil/data/models/servicio.dart';
import 'package:parte_movil/data/models/paquete.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class AuxiliarService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Clientes
  Future<List<Cliente>> obtenerClientes({int page = 1, int pageSize = 1000}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}?page=$page&pageSize=$pageSize';
      
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

        return data.map((json) => Cliente.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener clientes: ${response.statusCode} - ${response.body}');
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

  Future<Cliente> crearCliente(Cliente cliente) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear cliente: $e');
    }
  }

  Future<Cliente> actualizarCliente(Cliente cliente) async {
    if (cliente.id == null || cliente.id == 0) {
      throw Exception('No se puede actualizar un cliente sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.clientes}/${cliente.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(cliente.toJson()),
      );

      if (response.statusCode == 200) {
        return Cliente.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return cliente;
      } else {
        throw Exception('Error al actualizar cliente: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar cliente: $e');
    }
  }

  // Barberos
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

  // Servicios
  Future<List<Servicio>> obtenerServicios({int page = 1, int pageSize = 1000}) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}?page=$page&pageSize=$pageSize';
      
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
        
        return data.map((json) => Servicio.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener servicios: ${response.statusCode} - ${response.body}');
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

  Future<Servicio> crearServicio(Servicio servicio) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(servicio.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Servicio.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear servicio: $e');
    }
  }

  Future<Servicio> actualizarServicio(Servicio servicio) async {
    if (servicio.id == null || servicio.id == 0) {
      throw Exception('No se puede actualizar un servicio sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}/${servicio.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(servicio.toJson()),
      );

      if (response.statusCode == 200) {
        return Servicio.fromJson(jsonDecode(response.body));
      } else if (response.statusCode == 204) {
        return servicio;
      } else {
        throw Exception('Error al actualizar servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar servicio: $e');
    }
  }

  Future<void> eliminarServicio(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.servicios}/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar servicio: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar servicio: $e');
    }
  }

  Future<void> cambiarEstadoServicio(int id, bool estado) async {
    try {
      // Obtenemos el servicio actual primero
      final servicios = await obtenerServicios();
      final actual = servicios.firstWhere((s) => s.id == id);
      
      final actualizado = Servicio(
        id: actual.id,
        nombre: actual.nombre,
        descripcion: actual.descripcion,
        precio: actual.precio,
        duracionMinutos: actual.duracionMinutos,
        estado: estado,
        imagen: actual.imagen,
      );

      await actualizarServicio(actualizado);
    } catch (e) {
      throw Exception('Error al cambiar estado del servicio: $e');
    }
  }

  // Paquetes
  Future<List<Paquete>> obtenerPaquetes() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.paquetes}?pageSize=1000';
      
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

        return data.map((json) => Paquete.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener paquetes: ${response.statusCode} - ${response.body}');
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

  // Productos
  Future<List<Producto>> obtenerProductos() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}?pageSize=1000';
      
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

        return data.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener productos: ${response.statusCode} - ${response.body}');
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

  // Subir imagen (Servicios, Perfiles, Productos, etc.)
  Future<String> subirImagen(String filePath, {List<int>? imageBytes, String? fileName}) async {
    try {
      final token = await _authService.getToken();
      final url = Uri.parse('${ApiConfig.baseUrl}/images/subir');
      final request = http.MultipartRequest('POST', url);
      
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      
      if (imageBytes != null && fileName != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'imagen', 
          imageBytes, 
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'imagen', 
          filePath,
          contentType: MediaType('image', 'jpeg'),
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
}

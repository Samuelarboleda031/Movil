import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:parte_movil/core/network/api_config.dart';
import 'package:parte_movil/data/models/producto.dart';
import 'package:parte_movil/data/models/categoria.dart';
import 'package:parte_movil/data/datasources/auth_service.dart';

class ProductoService {
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ================= CATÉGORIAS =================
  Future<List<Categoria>> getCategorias() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}/Categorias?page=1&pageSize=1000';
      
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);
        
        List<dynamic> data = [];
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        }

        return data.map((json) => Categoria.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener categorías: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener categorías: $e');
    }
  }

  // ================= PRODUCTOS =================
  Future<List<Producto>> getProductos() async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}?page=1&pageSize=1000';
      
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
        final dynamic rawData = jsonDecode(response.body);
        
        List<dynamic> data = [];
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        }

        return data.map((json) => Producto.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener productos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener productos: $e');
    }
  }

  Future<Producto?> getProductoById(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}/$id';
      
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        return Producto.fromJson(jsonDecode(response.body));
      }
      return null;
    } catch (e) {
      throw Exception('Error al obtener producto por ID: $e');
    }
  }

  Future<Producto> createProducto(Producto producto) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}';

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(producto.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Producto.fromJson(jsonDecode(response.body));
      } else {
        throw Exception('Error al crear producto: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al crear producto: $e');
    }
  }

  Future<Producto> updateProducto(Producto producto) async {
    if (producto.id == null || producto.id == 0) {
      throw Exception('No se puede actualizar un producto sin ID');
    }

    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}/${producto.id}';

      final response = await http.put(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode(producto.toJson()),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        if (response.body.isNotEmpty && response.statusCode != 204) {
          return Producto.fromJson(jsonDecode(response.body));
        }
        return producto;
      } else {
        throw Exception('Error al actualizar producto: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al actualizar producto: $e');
    }
  }

  Future<void> deleteProducto(int id) async {
    try {
      final headers = await _getHeaders();
      final url = '${ApiConfig.baseUrl}${ApiConfig.productos}/$id';

      final response = await http.delete(
        Uri.parse(url),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Error al eliminar producto: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al eliminar producto: $e');
    }
  }

  Future<Producto> toggleProductoActivo(int id) async {
    try {
      final headers = await _getHeaders();
      final producto = await getProductoById(id);
      if (producto == null) throw Exception('Producto no encontrado');
      
      final nuevoEstado = !producto.activo;
      
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.productos}/$id/estado'),
        headers: headers,
        body: jsonEncode({"Estado": nuevoEstado, "Activo": nuevoEstado}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return (await getProductoById(id))!;
      } else {
        throw Exception('Error al cambiar estado del producto: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al cambiar estado: $e');
    }
  }
}

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:parte_movil/data/models/usuario.dart';
import 'package:parte_movil/core/network/api_config.dart';

class AuthService {
  static const String _userKey = 'user_data';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ─── USUARIO API METHODS (Merged from UsuarioService) ───────────────────────
  
  Future<List<Usuario>> obtenerUsuarios() async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}?pageSize=1000';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        if (response.body.isEmpty) return [];
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
        return data.map((json) => Usuario.fromJson(json)).toList();
      } else {
        throw Exception('Error al obtener usuarios: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error de conexión al obtener usuarios: $e');
    }
  }

  Future<Usuario?> obtenerUsuarioPorCorreo(String correo) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}?q=${Uri.encodeComponent(correo)}&pageSize=10';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final dynamic rawData = jsonDecode(response.body);
        List<dynamic> data;
        if (rawData is List) {
          data = rawData;
        } else if (rawData is Map && rawData.containsKey('items')) {
          data = rawData['items'];
        } else {
          data = [];
        }
        final usuarios = data.map((json) => Usuario.fromJson(json)).toList();
        try {
          return usuarios.firstWhere(
            (u) => u.correo.toLowerCase() == correo.toLowerCase(),
          );
        } catch (_) {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Usuario> crearUsuario(Usuario usuario) async {
    final url = '${ApiConfig.baseUrl}${ApiConfig.usuarios}';
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(usuario.toJson()),
      );
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
        headers: {'Content-Type': 'application/json'},
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

  // ─── AUTH LOGIC ────────────────────────────────────────────────────────────

  // Inicia sesión con correo y contraseña
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Inicia sesión con Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error en Google Sign-In: $e');
      rethrow;
    }
  }

  // Registra un nuevo usuario
  Future<UserCredential> signUp(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // Envía correo para restablecer contraseña. Retorna true si se envió correctamente.
  Future<bool> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  // Envia verificación de correo al usuario actual
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // Cierra sesión
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    
    try {
      if (await _googleSignIn.isSignedIn() == true) {
        await _googleSignIn.disconnect();
        await _googleSignIn.signOut();
      }
    } catch (e) {
      print('Error durante el cierre de sesión de Google: $e');
    }
    
    await _auth.signOut();
  }

  Future<String?> getToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      return await user.getIdToken();
    } catch (_) {
      return null;
    }
  }

  Future<Usuario?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return Usuario.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  Future<bool> isLoggedIn() async {
    if (_auth.currentUser != null) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey) != null;
  }

  User? get currentUser => _auth.currentUser;

  // Sincroniza el usuario autenticado de Firebase con la API (tabla Usuarios)
  Future<Usuario?> syncUsuarioConApi({required int rolId, String? contrasena}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    final correo = user.email!;
    final passwordValue = contrasena ?? 'firebase_auth';

    try {
      Usuario? existente = await obtenerUsuarioPorCorreo(correo);
      Usuario sincronizado;

      if (existente == null) {
        String nombre = 'Cliente';
        String apellido = 'Nuevo';
        
        if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
          final parts = user.displayName!.split(' ');
          nombre = parts[0];
          if (parts.length > 1) {
            apellido = parts.sublist(1).join(' ');
          }
        }

        final nuevo = Usuario(
          correo: correo,
          nombre: nombre,
          apellido: apellido,
          fotoPerfil: user.photoURL,
          contrasena: passwordValue,
          rolId: rolId,
          estado: true,
        );
        sincronizado = await crearUsuario(nuevo);
      } else {
        final rolFinal = existente.rolId ?? rolId;
        
        if (existente.rolId != rolFinal || existente.estado != true) {
          final actualizado = Usuario(
            id: existente.id,
            correo: existente.correo,
            contrasena: existente.contrasena ?? passwordValue,
            rolId: rolFinal,
            estado: true,
          );
          sincronizado = await actualizarUsuario(actualizado);
        } else {
          sincronizado = existente;
        }
      }

      await _saveApiUser(sincronizado);
      return sincronizado;
    } catch (e) {
      print('Error sincronizando usuario con API: $e');
      return null;
    }
  }

  Future<Usuario?> fetchUsuarioDesdeApi() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return null;

    try {
      print('[AuthService] Consultando usuario API para ${user.email}');
      final usuario = await obtenerUsuarioPorCorreo(user.email!);
      if (usuario != null) {
        await _saveApiUser(usuario);
      }
      return usuario;
    } catch (e) {
      print('[AuthService] Error obteniendo usuario desde API: $e');
      return null;
    }
  }

  Future<void> _saveApiUser(Usuario usuario) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(usuario.toJson()));
  }
}
